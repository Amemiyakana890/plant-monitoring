/// GET /plants が0件を返した(=まだ植物が1件も登録されていない)ことを表す例外。
///
/// これまでは通信エラー(サーバー停止・ネットワーク不通など)と区別せず
/// 汎用的な[StateError]を投げていたため、[PlantStore]側で「未登録なので
/// 登録画面へ誘導する」と「通信エラーなので再試行を促す」を区別できなかった。
/// この例外を専用に用意することで、呼び出し側(PlantStore.loadPlant())が
/// catch節で明示的に振る舞いを分けられるようにする。
///
/// v1は「1台1株」の制約(要件定義書9章)のため、GET /plantsが1件も
/// 返さない状態はほぼ「初回起動でまだ登録していない」ケースに限られる想定。
class PlantNotRegisteredException implements Exception {
  const PlantNotRegisteredException();

  @override
  String toString() => 'PlantNotRegisteredException: まだ植物が登録されていません';
}
