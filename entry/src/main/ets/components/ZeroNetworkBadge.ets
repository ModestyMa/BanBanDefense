// 零联网徽章（C2，mini-SPEC §2.2.3）：圆角胶囊 + 🛡 + 「0 网络权限」
// 使用位置：隐私宣言页顶部、首启隐私弹窗；商店首图由 T11 上架专员引用同文案
@ComponentV2
export struct ZeroNetworkBadge {
  build() {
    Row({ space: 6 }) {
      Text('🛡')
        .fontSize(14)
      Text($r('app.string.badge_zero_network'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary'))
    }
    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
    .backgroundColor($r('app.color.today_bg'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.primary') })
  }
}
