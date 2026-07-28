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
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor('#F0764F')
      .backgroundColor('#F2FFFFFF')
      .borderRadius(12)
      .height(32)
      .padding({ left: 2, right: 2, top: 0, bottom: 0 })
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
          .fontSize(40)
        Blank()
        Text(this.levelText)
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

      Text(this.streakText)
        .fontSize(12)
        .fontColor('#E6FFFFFF')

      Row({ space: 6 }) {
        this.actionButton($r('app.string.card_btn_quick_add'), 'quickAdd')
        this.actionButton($r('app.string.card_btn_pomodoro'), 'pomodoro')
        this.actionButton($r('app.string.card_btn_countdown'), 'countdownAdd')
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 10 })
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
