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
  @LocalStorageProp('level') level: number = 1;
  @LocalStorageProp('streakDays') streakDays: number = 0;

  @Builder
  actionButton(label: Resource, target: string) {
    Button(label)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor('#F0764F')
      .backgroundColor('#F2FFFFFF')
      .borderRadius(14)
      .height(38)
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
    Column({ space: 8 }) {
      Row() {
        Text(this.moodEmoji)
          .fontSize(50)
        Blank()
        Text($r('app.string.card_level_prefix') + this.level.toString())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#59FFFFFF')
          .borderRadius(14)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      }
      .width('100%')

      Text(this.moodText)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text($r('app.string.card_streak_prefix') + this.streakDays.toString() + $r('app.string.card_streak_suffix'))
        .fontSize(12)
        .fontColor('#E6FFFFFF')

      Row({ space: 8 }) {
        this.actionButton($r('app.string.card_btn_quick_add'), 'quickAdd')
        this.actionButton($r('app.string.card_btn_pomodoro'), 'pomodoro')
        this.actionButton($r('app.string.card_btn_countdown'), 'countdownAdd')
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 14 })
    .linearGradient({
      angle: 135,
      colors: [['#FF8A65', 0.0], ['#FFB08A', 0.55], ['#FFD9CE', 1.0]]
    })
    .borderRadius(24)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { 'target': 'home' }
      });
    })
  }
}
