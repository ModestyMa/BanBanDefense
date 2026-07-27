// 隐私政策页（SPEC_M5 4.4）：读取 rawfile/privacy_policy.txt 全文展示，不依赖网络
import { router } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ResponsiveContainer } from '../../components/ResponsiveContainer';

const DOMAIN: number = 0x1504;
const TAG: string = 'PrivacyPolicyPage';
const RAWFILE_NAME: string = 'privacy_policy.txt';

@Entry
@ComponentV2
struct PrivacyPolicyPage {
  @Local content: string = '';

  aboutToAppear(): void {
    const rm = getContext(this).resourceManager;
    rm.getRawFileContent(RAWFILE_NAME)
      .then((data: Uint8Array) => {
        this.content = util.TextDecoder.create('utf-8').decodeToString(data);
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '隐私政策加载失败: %{public}s', JSON.stringify(err));
        this.content = getContext(this).resourceManager.getStringSync($r('app.string.privacy_load_failed'));
      });
  }

  @Builder
  navBar() {
    Row() {
      Text('‹ ' + getContext(this).resourceManager.getStringSync($r('app.string.action_back')))
        .fontSize(15)
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          router.back();
        })
      Text($r('app.string.settings_privacy'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({ right: 40 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 12 })
  }

  build() {
    Column() {
      ResponsiveContainer({ bgColor: $r('app.color.page_bg') }) {
      Column() {
        this.navBar()
        Scroll() {
          Text(this.content)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(24)
            .width('100%')
            .padding({ left: 20, right: 20, top: 4, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .height('100%')
    }
    }
    .width('100%')
    .height('100%')
  }
}
