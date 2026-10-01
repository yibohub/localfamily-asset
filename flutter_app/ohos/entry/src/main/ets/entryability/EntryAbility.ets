import { AbilityConstant, Want } from '@kit.AbilityKit';
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';

/**
 * Flutter 宿主 Ability。
 *
 * 生命周期、窗口与 Flutter 引擎的绑定全部由 FlutterAbility 基类接管，
 * 引擎随 Ability 创建/销毁；如需注册平台通道/插件，在
 * configureFlutterEngine 中通过 engine.plugins/注册器添加。
 */
export default class EntryAbility extends FlutterAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam);
  }

  configureFlutterEngine(engine: FlutterEngine): void {
    super.configureFlutterEngine(engine);
  }

  cleanUpFlutterEngine(engine: FlutterEngine): void {
    super.cleanUpFlutterEngine(engine);
  }
}
