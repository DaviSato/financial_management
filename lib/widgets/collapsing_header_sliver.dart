import 'package:flutter/material.dart';

/// `SliverAppBar` com uma toolbar **fixa** (título + ações) e uma faixa abaixo
/// que **colapsa ao rolar e volta com snap** ao rolar um pouco de volta.
///
/// Precisa ser um único `SliverAppBar`: empilhar um app bar pinned + um sliver
/// floating separado não funciona, porque o floating ignora o `overlap` do
/// pinned (`paintOrigin: min(overlap, 0)`) e acaba pintando atrás da toolbar.
/// Aqui o próprio app bar cuida da parte fixa (toolbar) e da parte colapsável
/// (o [header], no `flexibleSpace`), então não há sobreposição.
///
/// O [header] tem altura fixa [headerHeight] e fica ancorado logo abaixo da
/// toolbar; ao colapsar ele é recortado (de baixo para cima) e some — sem
/// esmagar os widgets internos. `snap` traz tudo de volta inteiro.
class CollapsingHeaderSliver extends StatelessWidget {
  const CollapsingHeaderSliver({
    super.key,
    required this.title,
    required this.headerHeight,
    required this.header,
    this.actions,
  });

  final Widget title;
  final List<Widget>? actions;

  /// Altura fixa da faixa colapsável. O [header] deve caber nela.
  final double headerHeight;

  /// Conteúdo da faixa (ex.: seletor de mês, filtros).
  final Widget header;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      title: title,
      actions: actions,
      surfaceTintColor: Colors.transparent,
      collapsedHeight: kToolbarHeight,
      expandedHeight: kToolbarHeight + headerHeight,
      flexibleSpace: FlexibleSpaceBar(
        // `parallax`: o conteúdo desliza levemente para cima ao colapsar
        // (além de desaparecer com fade), dando o efeito de deslize.
        collapseMode: CollapseMode.parallax,
        background: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: headerHeight,
            width: double.infinity,
            child: header,
          ),
        ),
      ),
    );
  }
}
