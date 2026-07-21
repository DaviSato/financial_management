import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'logo_config.dart';

/// Um resultado da busca por nome (Brand Search API).
class BrandHit {
  final String name;
  final String domain;
  final String logoUrl;

  const BrandHit({
    required this.name,
    required this.domain,
    required this.logoUrl,
  });
}

/// Baixa logos de marca do logo.dev UMA vez e guarda em disco, na pasta privada
/// do app. Depois disso a lista de gastos e o dashboard leem só o arquivo local
/// — nenhuma chamada externa por render (offline, privado e sem gastar cota).
///
/// O modelo guarda apenas o domínio (ex.: "itau.com.br"); o caminho do arquivo é
/// remontado em runtime a partir do diretório do app, nunca salvo absoluto (o
/// diretório pode mudar entre execuções/plataformas).
///
/// A imagem é baixada colorida; deixar monocromático ("como ícone") é decisão de
/// exibição — aplicar um filtro no widget é mais flexível que gravar em cinza,
/// pois não invalida o cache se você mudar de ideia.
class LogoService {
  LogoService._();
  static final LogoService _instance = LogoService._();
  factory LogoService() => _instance;

  static const _subdir = 'brand_logos';

  /// 128px cobre retina (2x) em avatares de ~44-64px sem pesar.
  static const _size = 128;

  Directory? _dirCache;

  Future<Directory> _dir() async {
    if (_dirCache != null) return _dirCache!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$_subdir');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dirCache = dir;
    return dir;
  }

  /// Nome de arquivo estável e seguro a partir do domínio.
  String _fileName(String domain) {
    final safe = domain.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.-]'), '_');
    return '$safe.png';
  }

  /// O arquivo local do logo — exista ele ou não em disco.
  Future<File> fileFor(String domain) async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}${_fileName(domain)}');
  }

  /// Busca marcas por nome na Brand Search API (usa a chave secreta). Retorna
  /// lista vazia se não há chave secreta, a busca falha ou está offline.
  Future<List<BrandHit>> search(String query) async {
    final secret = LogoConfig().secretKey;
    final q = query.trim();
    if (secret.isEmpty || q.isEmpty) return const [];

    final uri = Uri.https('api.logo.dev', '/search', {'q': q});
    try {
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $secret'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];

      final data = jsonDecode(res.body);
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((m) => BrandHit(
                name: (m['name'] as String?) ?? '',
                domain: (m['domain'] as String?) ?? '',
                logoUrl: (m['logo_url'] as String?) ?? '',
              ))
          .where((h) => h.domain.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// True se o logo já está em disco (nenhuma rede envolvida). É o que garante
  /// o dedup: quem já tem o arquivo nunca re-baixa.
  Future<bool> hasLocal(String domain) async =>
      (await fileFor(domain)).exists();

  /// O arquivo local se ele existir, senão null — sem tocar a rede.
  /// Usado na renderização (BrandAvatar) e para preview de logo já baixado.
  Future<File?> localIfExists(String domain) async {
    final file = await fileFor(domain);
    return file.existsSync() ? file : null;
  }

  /// Garante o logo em disco: devolve o arquivo local, baixando 1x se faltar.
  /// Se já existe, NÃO baixa de novo. Retorna null se não há token, o download
  /// falha ou está offline — nesses casos o chamador cai no fallback.
  Future<File?> ensureLocal(String domain) async {
    final existing = await localIfExists(domain);
    if (existing != null) return existing;
    return download(domain);
  }

  /// Busca os bytes do logo no logo.dev, SEM gravar em disco. Serve ao preview:
  /// mostra a imagem antes de o usuário confirmar. Retorna null em falha.
  Future<Uint8List?> fetchBytes(String domain) async {
    final token = LogoConfig().token;
    if (token.isEmpty || domain.trim().isEmpty) return null;

    final uri = Uri.https('img.logo.dev', '/$domain', {
      'token': token,
      'size': '$_size',
      'format': 'png',
    });

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      return res.bodyBytes;
    } catch (_) {
      // Offline, timeout, DNS etc. — sem exceção pra cima; o chamador decide.
      return null;
    }
  }

  /// Grava bytes já em mãos (ex.: os do preview) no arquivo local do domínio.
  /// Evita um segundo download ao confirmar a escolha.
  Future<File> saveBytes(String domain, Uint8List bytes) async {
    final file = await fileFor(domain);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Baixa (ou re-baixa) o logo do logo.dev e salva em disco, sobrescrevendo.
  /// Retorna o arquivo salvo, ou null em falha.
  Future<File?> download(String domain) async {
    final bytes = await fetchBytes(domain);
    if (bytes == null) return null;
    return saveBytes(domain, bytes);
  }

  /// Remove o logo local de um domínio (ex.: ao trocar/limpar a marca).
  Future<void> deleteLocal(String domain) async {
    try {
      final file = await fileFor(domain);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Some na próxima limpeza; não vale interromper o fluxo por isso.
    }
  }
}
