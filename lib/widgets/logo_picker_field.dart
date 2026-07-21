import 'dart:async';

import 'package:flutter/material.dart';

import '../services/logo_config.dart';
import '../services/logo_service.dart';
import 'brand_avatar.dart';

/// Campo inline (dentro do formulário de gasto) para buscar e escolher o logo
/// da marca por nome. Ao tocar num resultado, o logo é baixado uma vez e
/// guardado no aparelho (dedup via [LogoService.ensureLocal]); a lista passa a
/// ler o arquivo local.
class LogoPickerField extends StatefulWidget {
  final String? logoDomain;
  final Color color;
  final ValueChanged<String?> onChanged;

  const LogoPickerField({
    super.key,
    required this.logoDomain,
    required this.color,
    required this.onChanged,
  });

  @override
  State<LogoPickerField> createState() => _LogoPickerFieldState();
}

class _LogoPickerFieldState extends State<LogoPickerField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<BrandHit> _results = const [];
  bool _searching = false;
  String? _downloading; // domínio sendo baixado no momento
  int _requestId = 0;

  bool get _hasSecret => LogoConfig().hasSecret;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    final reqId = ++_requestId;
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final hits = await LogoService().search(q);
    if (reqId != _requestId || !mounted) return;
    setState(() {
      _results = hits;
      _searching = false;
    });
  }

  Future<void> _pick(BrandHit hit) async {
    setState(() => _downloading = hit.domain);
    // ensureLocal faz o dedup: se já está em disco, não re-baixa.
    final file = await LogoService().ensureLocal(hit.domain);
    if (!mounted) return;
    setState(() => _downloading = null);
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não consegui baixar o logo. Verifique a conexão.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _controller.clear();
    setState(() => _results = const []);
    widget.onChanged(hit.domain);
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = (widget.logoDomain ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BrandAvatar(logoDomain: widget.logoDomain, color: widget.color),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: _hasSecret,
                autocorrect: false,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  labelText: 'Logo da marca',
                  hintText: _hasSecret
                      ? 'Buscar por nome (ex: nubank)'
                      : 'Configure a chave de busca no Perfil',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : hasLogo
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Remover logo',
                              onPressed: () => widget.onChanged(null),
                            )
                          : null,
                ),
              ),
            ),
          ],
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 4),
          ..._results.take(6).map(_resultTile),
        ],
      ],
    );
  }

  Widget _resultTile(BrandHit hit) {
    final downloading = _downloading == hit.domain;
    return InkWell(
      onTap: downloading ? null : () => _pick(hit),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            _thumb(hit.logoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.name.isEmpty ? hit.domain : hit.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    hit.domain,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (downloading)
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.add_rounded, size: 18, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String url) {
    const s = 40.0;
    return Container(
      width: s,
      height: s,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: url.isEmpty
          ? _thumbFallback()
          : Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _thumbFallback(),
              errorBuilder: (_, _, _) => _thumbFallback(),
            ),
    );
  }

  Widget _thumbFallback() =>
      const Icon(Icons.image_outlined, size: 18, color: Colors.white24);
}
