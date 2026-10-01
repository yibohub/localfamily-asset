import { FlutterEntry } from '@ohos/flutter_ohos';

/**
 * Flutter 视图宿主页：由 FlutterEntry 提供 ArkUI 平台视图，
 * 并把页面生命周期（前后台/返回键）桥接到 Flutter 引擎。
 */
@Entry
struct Index {
  private flutterEntry: FlutterEntry | null = null;

  aboutToAppear(): void {
    this.flutterEntry = new FlutterEntry(getContext(this) as ESObject);
    this.flutterEntry.onAboutToAppear();
  }

  aboutToDisappear(): void {
    this.flutterEntry?.onAboutToDisappear();
  }

  onPageShow(): void {
    this.flutterEntry?.onPageShow();
  }

  onPageHide(): void {
    this.flutterEntry?.onPageHide();
  }

  onBackPress(): boolean {
    return this.flutterEntry?.onBackPress() ?? false;
  }

  build() {
    Stack() {
      this.flutterEntry?.getFlutterView()
    }
  }
}
