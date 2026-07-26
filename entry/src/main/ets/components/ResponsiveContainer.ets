// 限宽居中容器（SPEC_M6 决策 3）：内容最大宽 640vp，宽屏水平居中两侧留白；手机端行为不变
// 用法：页面 build 根布局外包一层 ResponsiveContainer() { ... }，页面背景色移到容器上
@ComponentV2
export struct ResponsiveContainer {
  @BuilderParam content: () => void = ResponsiveContainer.emptyContent;

  @Builder
  static emptyContent() {
  }

  build() {
    Row() {
      Blank()
      Column() {
        this.content()
      }
      .width('100%')
      .constraintSize({ maxWidth: 640 })
      .height('100%')
      Blank()
    }
    .width('100%')
    .height('100%')
  }
}
