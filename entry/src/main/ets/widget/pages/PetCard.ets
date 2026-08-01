// 伴伴宠物卡片 UI（ArkTS 卡片受限子集：允许使用 V1 装饰器，见决策 D-004 豁免条款）
// 数据由 PetFormAbility/PetCardService 通过 FormBindingData 推送（LocalStorage 通道）
// 假设API清单（人工核验后删除）:
// 1. postCardAction(this, { action:'router', abilityName, params }) 在卡片 Button/根容器 onClick 中可用
// 2. 卡片受限子集支持 Column/Row/Stack/Text/Button 与 linearGradient（若不支持渐变则降级纯色，见交付说明）

let storage = new LocalStorage();

@Entry(storage)
@Component
struct PetCard {
  @LocalStorageProp('moodEmoji') moodEmoji: string = '😺';
  @LocalStorageProp('moodText') moodText: string = '今天也要加油哦';
  @LocalStorageProp('levelText') levelText: string = 'Lv.1';
  @LocalStorageProp('streakText') streakText: string = '🔥 连续 0 天';

  @Builder
  actionButton(label: Resource, target: string) {
    Button(label)
      .fontSize($r('app.float.fontSize_14'))
      .fontColor($r('app.color.card_btn_text'))
      .backgroundColor($r('app.color.card_btn_bg'))
      .borderRadius($r('app.float.borderRadius_12'))
      .height($r('app.float.height_32'))
      .padding(0)
      .layoutWeight(1)
      .onClick(() => {
        postCardAction(this, {
          action: 'router',
          abilityName: 'EntryAbility',
          params: { 'target': target }
        });
      })
  }

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.moodEmoji)
          .fontSize($r('app.float.fontSize_40'))
        Blank()
        Text(this.levelText)
          .fontSize($r('app.float.fontSize_13'))
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.card_level_bg'))
          .borderRadius($r('app.float.borderRadius_14'))
          .padding({ left:$r('app.float.padding_left_12'), right:$r('app.float.padding_right_12'), top:$r('app.float.padding_top_4'), bottom:$r('app.float.padding_bottom_4') })
      }
      .width('100%')

      Text(this.moodText)
        .fontSize($r('app.float.fontSize_15'))
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.streakText)
        .fontSize($r('app.float.fontSize_12'))
        .fontColor($r('app.color.card_streak_text'))

      Row({ space: 6 }) {
        this.actionButton($r('app.string.card_btn_quick_add'), 'quickAdd')
        this.actionButton($r('app.string.card_btn_pomodoro'), 'pomodoro')
        this.actionButton($r('app.string.card_btn_countdown'), 'countdownAdd')
      }
      .width('100%')
      .margin({ top:$r('app.float.margin_top_4') })
    }
    .width('100%')
    .height('100%')
    .padding({ left:$r('app.float.padding_left_18'), right:$r('app.float.padding_right_18'), top:$r('app.float.padding_top_16'), bottom:$r('app.float.padding_bottom_10') })
    .linearGradient({
      angle: 135,
      colors: [[$r('app.color.card_grad_start'), 0.0], [$r('app.color.card_grad_mid'), 0.55], [$r('app.color.card_grad_end'), 1.0]]
    })
    .borderRadius($r('app.float.borderRadius_24'))
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { 'target': 'home' }
      });
    })
  }
}
