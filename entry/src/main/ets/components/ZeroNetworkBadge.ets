// 零联网徽章（C2，mini-SPEC §2.2.3）：圆角胶囊 + 🛡 + 「0 网络权限」
// 使用位置：隐私宣言页顶部、首启隐私弹窗；商店首图由 T11 上架专员引用同文案
@ComponentV2
export struct ZeroNetworkBadge {
  build() {
    Row({ space: 6 }) {
      Text('🛡')
        .fontSize($r('app.float.fontSize_14'))
      Text($r('app.string.badge_zero_network'))
        .fontSize($r('app.float.fontSize_13'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary'))
    }
    .padding({ left:$r('app.float.padding_left_14'), right:$r('app.float.padding_right_14'), top:$r('app.float.padding_top_6'), bottom:$r('app.float.padding_bottom_6') })
    .backgroundColor($r('app.color.today_bg'))
    .borderRadius($r('app.float.borderRadius_16'))
    .border({ width: 1, color: $r('app.color.primary') })
  }
}
