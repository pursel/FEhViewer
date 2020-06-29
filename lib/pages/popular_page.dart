import 'package:FEhViewer/client/parser/gallery_list_parser.dart';
import 'package:FEhViewer/generated/l10n.dart';
import 'package:FEhViewer/models/entity/gallery.dart';
import 'package:FEhViewer/widget/eh_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'item/gallery_item.dart';

class PopularListTab extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _PopularListTab();
}

class _PopularListTab extends State<PopularListTab> {
  List<GalleryItemBean> _gallerItemBeans = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  _loadData() async {
    setState(() {
      _gallerItemBeans.clear();
      _loading = true;
    });
    var gallerItemBeans = await GalleryListParser.getPopular();
    _gallerItemBeans.addAll(gallerItemBeans);
    setState(() {
      _loading = false;
    });
  }

  // _reloadData() async {
  //   var gallerItemBeans = await GalleryListParser.getPopular();
  //   setState(() {
  //     _gallerItemBeans.clear();
  //     _gallerItemBeans.addAll(gallerItemBeans);
  //   });
  // }
  _reloadData() async {
    var gallerItemBeans = await GalleryListParser.getPopular();

    setState(() {
      _gallerItemBeans.clear();
      _gallerItemBeans.addAll(gallerItemBeans);
    });
  }

  SliverList gallerySliverListView(List gallerItemBeans) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < gallerItemBeans.length) {
            return GalleryItemWidget(galleryItemBean: gallerItemBeans[index]);
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var ln = S.of(context);
    var _title = ln.tab_popular;
    CustomScrollView customScrollView = CustomScrollView(
      slivers: <Widget>[
        CupertinoSliverNavigationBar(
          largeTitle: TabPageTitle(
            title: _title,
            isLoading: _loading,
          ),
          transitionBetweenRoutes: false,
        ),
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            await _reloadData();
          },
        ),
        SliverSafeArea(
          top: false,
          sliver: gallerySliverListView(_gallerItemBeans),
        )
      ],
    );

    return customScrollView;
  }
}