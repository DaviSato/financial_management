/// De onde veio um lançamento.
///
/// Separa o que o usuário digitou/confirmou do que a importação automática
/// criou sozinha — independente da categoria, para que a distinção sobreviva a
/// uma recategorização posterior.
///
/// Um item vindo de notificação mas confirmado pelo formulário conta como
/// [manual]: houve revisão. Só o criado sem interação é [automatic].
enum EntryOrigin {
  manual,
  automatic;

  String get label => switch (this) {
    EntryOrigin.manual => 'Manual',
    EntryOrigin.automatic => 'Automático',
  };

  bool get isAutomatic => this == EntryOrigin.automatic;

  /// Lançamentos antigos não têm o campo — assume [manual], que é o que eram.
  static EntryOrigin fromString(String? value) {
    if (value == null || value.isEmpty) return EntryOrigin.manual;
    for (final origin in EntryOrigin.values) {
      if (origin.name == value) return origin;
    }
    return EntryOrigin.manual;
  }
}
