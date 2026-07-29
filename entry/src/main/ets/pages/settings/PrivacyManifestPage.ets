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
        .fontSize(15)
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          router.back();
        })
      Text($r('app.string.settings_privacy_promise'))
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

  @Builder
  paragraph(text: Resource) {
    Text(text)
      .fontSize(15)
      .fontColor($r('app.color.text_primary'))
      .lineHeight(26)
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
                .fontSize(56)
                .margin({ top: 12 })
              ZeroNetworkBadge()
              Text($r('app.string.privacy_manifest_title'))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Column({ space: 14 }) {
                this.paragraph($r('app.string.privacy_manifest_p1'))
                this.paragraph($r('app.string.privacy_manifest_p2'))
                this.paragraph($r('app.string.privacy_manifest_p3'))
                Text($r('app.string.privacy_manifest_p4'))
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary'))
                  .lineHeight(26)
                  .width('100%')
              }
              .width('100%')
              .padding(20)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(16)
            }
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 24 })
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
