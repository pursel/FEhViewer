import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_http_cache/dio_http_cache.dart';
import 'package:fehviewer/common/controller/advance_search_controller.dart';
import 'package:fehviewer/common/global.dart';
import 'package:fehviewer/const/const.dart';
import 'package:fehviewer/models/base/eh_models.dart';
import 'package:fehviewer/pages/tab/controller/search_page_controller.dart';
import 'package:fehviewer/pages/tab/fetch_list.dart';
import 'package:fehviewer/utils/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'app_dio/pdio.dart';
import 'gallery_request.dart';

Options getCacheOptions({bool forceRefresh = false, Options? options}) {
  return buildCacheOptions(
    const Duration(days: 5),
    maxStale: const Duration(days: 7),
    forceRefresh: forceRefresh,
    options: options,
  );
}

Future<GalleryList?> getPopular() async {
  DioHttpClient dioHttpClient = DioHttpClient(dioConfig: ehDioConfig);
  DioHttpResponse httpResponse = await dioHttpClient.get(
    '/popular',
    httpTransformer: GalleryListHttpTransformer(),
  );

  if (httpResponse.ok && httpResponse.data is GalleryList) {
    return httpResponse.data as GalleryList;
  }
}

Future<GalleryList?> getGallery({
  int? page,
  String? fromGid,
  String? serach,
  int? cats,
  bool refresh = false,
  CancelToken? cancelToken,
  GalleryListType? galleryListType,
  String? toplist,
  String? favcat,
  ValueChanged<List<Favcat>>? favCatList,
}) async {
  final AdvanceSearchController _searchController = Get.find();
  DioHttpClient dioHttpClient = DioHttpClient(dioConfig: ehDioConfig);

  late final String _url;
  switch (galleryListType) {
    case GalleryListType.watched:
      _url = '/watched';
      break;
    case GalleryListType.toplist:
      _url = '${EHConst.EH_BASE_URL}/toplist.php';
      break;
    case GalleryListType.favorite:
      _url = '/favorites.php';
      break;
    default:
      _url = '/';
  }

  final isTopList = galleryListType == GalleryListType.toplist;
  final isFav = galleryListType == GalleryListType.favorite;

  final Map<String, dynamic> _params = <String, dynamic>{
    'page': page ?? 0,
    if (!isTopList) 'f_cats': cats,
    if (fromGid != null) 'from': fromGid,
    if (!(galleryListType == GalleryListType.watched) &&
        !isTopList &&
        serach != null)
      'f_search': serach,
    if (isTopList && toplist != null && toplist.isNotEmpty) 'tl': toplist,
    if (isFav && favcat != null && favcat != 'a' && favcat.isNotEmpty)
      'favcat': favcat,
  };

  /// 高级搜索处理
  if (!isTopList && _searchController.enableAdvance) {
    _params['advsearch'] = 1;
    _params.addAll(_searchController.advanceSearchMap);
  }

  if (serach != null && isFav) {
    _params.addAll(_searchController.favSearchMap);
  }

  DioHttpResponse httpResponse = await dioHttpClient.get(
    _url,
    queryParameters: _params,
    httpTransformer:
        isFav ? FavoriteListHttpTransformer() : GalleryListHttpTransformer(),
    options: getCacheOptions(forceRefresh: refresh),
  );

  if (httpResponse.error is ListDisplayModeException) {
    logger.d(' inline_set dml');
    _params['inline_set'] = 'dm_l';

    httpResponse = await dioHttpClient.get(
      _url,
      queryParameters: _params,
      httpTransformer:
          isFav ? FavoriteListHttpTransformer() : GalleryListHttpTransformer(),
      options: getCacheOptions(forceRefresh: true),
    );
  }

  if (httpResponse.error is FavOrderException) {
    final _order = (httpResponse.error as FavOrderException).order;
    _params['inline_set'] = _order;
    _params.removeWhere((key, value) => key == 'page');
    httpResponse = await dioHttpClient.get(
      _url,
      queryParameters: _params,
      httpTransformer:
          isFav ? FavoriteListHttpTransformer() : GalleryListHttpTransformer(),
      options: getCacheOptions(forceRefresh: true),
    );
  }

  if (httpResponse.ok && httpResponse.data is GalleryList) {
    return httpResponse.data as GalleryList;
  }
}

Future<GalleryItem?> getGalleryDetail({
  required String inUrl,
  bool refresh = false,
  CancelToken? cancelToken,
}) async {
  final PersistCookieJar cookieJar = await Api.cookieJar;
  final List<Cookie> cookies =
      await cookieJar.loadForRequest(Uri.parse(Api.getBaseUrl()));
  cookies.add(Cookie('nw', '1'));
  cookieJar.saveFromResponse(Uri.parse(Api.getBaseUrl()), cookies);

  DioHttpClient dioHttpClient = DioHttpClient(dioConfig: ehDioConfig);
  DioHttpResponse httpResponse = await dioHttpClient.get(
    inUrl,
    httpTransformer: GalleryHttpTransformer(),
    options: getCacheOptions(forceRefresh: refresh),
  );
  logger.v('httpResponse.ok ${httpResponse.ok}');
  if (httpResponse.ok && httpResponse.data is GalleryItem) {
    return httpResponse.data as GalleryItem;
  }
}

Future<GalleryImage?> fetchImageInfo(
  String href, {
  bool refresh = false,
  String? sourceId,
  CancelToken? cancelToken,
}) async {
  final Map<String, dynamic> _params = {
    if (sourceId != null && sourceId.trim().isNotEmpty) 'nl': sourceId,
  };

  DioHttpClient dioHttpClient = DioHttpClient(dioConfig: ehDioConfig);
  DioHttpResponse httpResponse = await dioHttpClient.get(
    href,
    queryParameters: _params,
    httpTransformer: GalleryImageHttpTransformer(),
    options: getCacheOptions(forceRefresh: refresh),
  );

  if (httpResponse.ok && httpResponse.data is GalleryImage) {
    return (httpResponse.data as GalleryImage).copyWith(href: href);
  }
}

Future<List<GalleryImage>> getGalleryImage(
  String inUrl, {
  int? page,
  bool refresh = false,
  CancelToken? cancelToken,
}) async {
  final Map<String, dynamic> _params = {
    if (page != null) 'p': page,
  };
  DioHttpClient dioHttpClient = DioHttpClient(dioConfig: ehDioConfig);

  DioHttpResponse httpResponse = await dioHttpClient.get(
    inUrl,
    queryParameters: _params,
    httpTransformer: GalleryImageListHttpTransformer(),
    options: getCacheOptions(forceRefresh: refresh),
  );

  if (httpResponse.ok && httpResponse.data is List<GalleryImage>) {
    return httpResponse.data as List<GalleryImage>;
  } else {
    return [];
  }
}
