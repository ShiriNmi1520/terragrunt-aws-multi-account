// viewer-request URI rewrite 範例,照自己站台的路由需求增刪規則。
// rewrite 後的 URI 就是 CloudFront 的 cache key。
function handler(event) {
  var request = event.request;
  var uri = request.uri;
  var m;

  // /downloads/<id>.zip → /archives/<id>.zip
  m = uri.match(/^\/downloads\/([0-9a-z-]+\.zip)$/);
  if (m) {
    request.uri = '/archives/' + m[1];
    return request;
  }

  // /assets/... → /static/assets/...
  if (/^\/assets\//.test(uri)) {
    request.uri = '/static' + uri;
    return request;
  }

  // 其餘視為 SPA route:最後一段沒副檔名就回 app 的 index.html。
  // site 記得設 spa_fallback = false,不然資產 404 會被 error response 蓋成 200
  var lastSeg = uri.split('/').pop();
  if (lastSeg.indexOf('.') === -1) {
    request.uri = '/app/index.html';
    return request;
  }

  return request;
}
