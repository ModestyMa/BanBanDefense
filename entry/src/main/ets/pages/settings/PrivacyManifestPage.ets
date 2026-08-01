// 隐私宣言页（C2，mini-SPEC §2.2.1）：静态图文，把"零网络权限"变成产品内可见资产
import { router } from '@kit.ArkUI';
import { ResponsiveContainer } from '../../components/ResponsiveContainer';
import { ZeroNetworkBadge } from '../../components/ZeroNetworkBadge';

@Entry
@ComponentV2
struct PrivacyManifestPage {
  @Builder
  navBar() {
    Row() {
      Text('‹ ' + getContext(this).resourceManager.getStringSync($r('app.string.action_back')))
        .fontSize($r('app.float.fontSize_15'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          router.back();
        })
      Text($r('app.string.settings_privacy_promise'))
        .fontSize($r('app.float.fontSize_17'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({ right:$r('app.float.margin_right_40') })
    }
    .width('100%')
    .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), top:$r('app.float.padding_top_6'), bottom:$r('app.float.padding_bottom_12') })
  }

  @Builder
  paragraph(text: Resource) {
    Text(text)
      .fontSize($r('app.float.fontSize_15'))
      .fontColor($r('app.color.text_primary'))
      .lineHeight($r('app.float.lineHeight_26'))
      .width('100%')
  }

  build() {
    Column() {
      ResponsiveContainer({ bgColor: $r('app.color.page_bg') }) {
        Column() {
          this.navBar()
          Scroll() {
            Column({ space: 20 }) {
              Text('🛡')
                .fontSize($r('app.float.fontSize_56'))
                .margin({ top:$r('app.float.margin_top_12') })
              ZeroNetworkBadge()
              Text($r('app.string.privacy_manifest_title'))
                .fontSize($r('app.float.fontSize_22'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Column({ space: 14 }) {
                this.paragraph($r('app.string.privacy_manifest_p1'))
                this.paragraph($r('app.string.privacy_manifest_p2'))
                this.paragraph($r('app.string.privacy_manifest_p3'))
                Text($r('app.string.privacy_manifest_p4'))
                  .fontSize($r('app.float.fontSize_15'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary'))
                  .lineHeight($r('app.float.lineHeight_26'))
                  .width('100%')
              }
              .width('100%')
              .padding($r('app.float.padding_20'))
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius($r('app.float.borderRadius_16'))
            }
            .width('100%')
            .padding({ left:$r('app.float.padding_left_20'), right:$r('app.float.padding_right_20'), bottom:$r('app.float.padding_bottom_24') })
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
