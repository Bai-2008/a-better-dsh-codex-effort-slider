# 更新日志

本分支基于上游 [dsh-codex-effort-slider](https://github.com/Microqian2th/dsh-codex-effort-slider) `1.0.0`。
下面是相对上游的**全部**改动（按主题归并，不是提交流水）。

---

## 1.3.10 — 再透一档；阴影不再被"一个框"裁掉

用户反馈（原话）："再透一点，然后阴影好像被一个框限制了。"

### 「框」是什么：`.cxp-root` 的 `overflow:auto` 把阴影裁成了矩形

`overflow` 会裁掉**后代**的 box-shadow，而阴影画在 `.cxp-panel` 上、壳层 `.cxp-root`
为了"矮窗口内部滚动"带着 `overflow:auto` —— 于是圆角面板外卖套了一圈**方角**光晕，
正是截图里那个"框"。

修法：**元素自身的 box-shadow 不受自身 overflow 影响**，所以把滚动安全网与阴影放到同一层：

- `.cxp-root{overflow:visible}` —— 只当定位壳，不裁任何东西；
- `.cxp-panel{overflow:auto}` + 行内 `max-height:pos.maxH`（渲染处把同一个值也写给面板）——
  矮窗口照旧内部滚动，安全网一点没少。

顺带修掉一个潜在问题：档位弹层（`.cxp-pop`，fixed）也是壳的子元素，以前同样可能被壳裁掉。

### 再透一档：**保留官方色相、只降 alpha**

官方菜单填充令牌 `--dsw-menu-surface-fill` 是浅色 `#f8f9fa94`（alpha .58）、深色 `#43454a73`（.45）。
现在取同色相的 **`.46` / `.40`**。

为什么不用 `color-mix(in srgb, var(--dsw-menu-surface-fill) 80%, transparent)` 去"把官方值调淡"：
那要求引擎支持 `color-mix`，不支持时**整条声明失效** —— 面板会变成**完全没有底色**，
比"不够透"糟得多。写死同色相的 rgba 则永远成立。

另外：推理等级**卡片**原来是**不透明**的 `--dsw-alias-bg-layer-2`，它盖住面板 2/3 的面积，
实心就把毛玻璃抵消了。现在也改成半透明（浅色 `rgba(255,255,255,.55)`、深色 `.06`）。

### 测试

第 35 节：那条"`.cxp-root` 带 overflow:auto"的断言**反过来**了 —— 现在必须
`overflow:visible`（并注明原因），同时断言 `.cxp-panel` 带 `overflow:auto`、
行内 `maxHeight` 与壳上那个**同值**。
第 38 节：底色断言改成"官方色相 + 比官方再透一档（alpha ≤ .5）"，
并新增"卡片也是半透明"两条。总数 **902 → 908**。

---

## 1.3.9 — 面板材料对齐官方菜单：毛玻璃 + 浅色主题下看得见的阴影

用户反馈（原话）："浅色主题时，面板跟背景颜色相似，周围加一层阴影吧，
官方的毛玻璃（微微透）的效果也要。"

### 照官方产物核对出来的三件事（都不是我发明的值）

1. **毛玻璃**：官方菜单材料用的是 `--dsw-menu-backdrop-filter: blur(40px) saturate(150%)`
   （主题包定义在 `body` 上；自定义属性会**继承**，所以 portal 到 body 的面板直接取得到）。
   字面值原样写进兜底，令牌改名了也还是官方那套观感。同时给 `-webkit-backdrop-filter`。
2. **半透明底**：模糊只有在"底是半透明的"时才看得见 —— 所以**不能**用我们原来的
   `--dsw-alias-bg-layer-1`（不透明色）。官方有专门的菜单填充令牌
   **`--dsw-menu-surface-fill`**：浅色 `#f8f9fa94`（≈58% 透）、深色 `#43454a73`（≈45% 透），
   正好就是"微微透"。取不到令牌时退到 `rgba(255,255,255,.72)` / `rgba(28,28,33,.72)`。
3. **阴影**：官方的 `--dsw-elevation-prominent` 是
   `stroke + 0 3px 8px #0000000a + 0 0 20px #0000000d` —— alpha 只有 4%~5%，
   在浅色页面上几乎看不见，这就是"面板跟背景一个颜色"的来源。
   现在叠上官方的 `--dsw-shadow-lv3`（`0 12px 32px #00000014`）再补一层更实的落地阴影；
   深色主题另给一套（黑得更实，浅色那套在深底上没有存在感）。
   主题切换靠 `body[data-ds-dark-theme] .cxp`（官方主题包也是挂在这个属性上）。

面板与**档位弹层**用同一种材料（官方菜单都这么做）——弹层叠在面板之上，双层模糊观感一致。

### 测试

第 38 节 +13 条（现在 902）：模糊用官方令牌且带官方字面兜底、`-webkit-` 前缀、
底必须是**半透明**（断言兜底 `rgba(...)` 的 alpha < 1，不透明底等于白做毛玻璃）、
浅色阴影里必须有 `--dsw-shadow-lv3`、深浅两套阴影不同、弹层同材料。
另外 `preview/panel.html`（背景 `#f5f5f5`，正是"面板跟背景像"的那种场景）重新生成过，
可以直接开它看观感。

---

## 1.3.8 — 换模型时的默认档位改成「正中（偶数档取中间的下一个）」

用户要求（原话）："所有模型点击使用的时候默认使用中间的档位，如果总档位是双数，就选中间的下一档，
比如总4档，默认第三档。"

### 规则

0 基下标 = `floor(n / 2)`（`defaultLevelIndex()`，两处共用同一条）：

| 总档数 | 下标 | 第几档（1 基） | 说明 |
| --- | --- | --- | --- |
| 1 | 0 | 第 1 档 | 唯一那档 |
| 2 | 1 | 第 2 档 | 中点在 1/2 之间 → 下一档 |
| 3 | 1 | 第 2 档 | 正中 |
| **4** | **2** | **第 3 档** | **用户给的例子** |
| 5 | 2 | 第 3 档 | 正中 |
| 6 | 3 | 第 4 档 | 中点在 3/4 之间 → 下一档 |

### 改了哪两处

1. **点击模型换模型时写回宿主的档位**（`switchModel`）：以前是"最后一档（Max）"，
   宿主的 `reasoning.defaultEffort` 在档位表里时就写它；现在一律写**正中**那一档；
2. **目录里"当前模型没有明确档位"时滑条停在哪**（`readCatalog`）：同上，以前最后一档。
   两处共用 `defaultLevelIndex()`，不会各写各的。

**显式档位优先**：会话里**明确存着**的 `reasoningEffort` 仍然压过这条规则（那是宿主的真实状态，
不能被默认值盖掉）——所以"你在 Max 上、点开面板"依旧显示 Max；只有"没有明确档位"时才落到正中。
宿主的 `defaultEffort`（`def`）**不再参与定位**（用户规则优先），字段本身保留在目录数据里。

另一条路（1.2.0 那半边「注入官方菜单」，默认关闭）**故意不动**：那边没有"点击模型"这个动作，
它镜像的是官方自己的语义 `reasoningEffort ?? defaultEffort`，改了反而与宿主不一致。

### 为什么以前没被发现

既有 868 条断言里**没有一条**盯住这个行为 —— 更巧的是测试台的默认模型
`DEFAULT_MODEL.reasoning.defaultEffort` **恰好就是 4 档的正中**（`"high"`），
新旧规则在那里答案完全相同。新增第 46 节（**19 条**）专门用"没有 defaultEffort"
和"defaultEffort 不是正中（low）"的模型把它区分出来：规则表 7 条 + 点击 4 档/5 档/2 档各写哪一档 +
"宿主 def 不参与定位" + "显式档位优先" + "面板打开就停在正中"。
总数 **868 → 887**。

---

## 1.3.7 — 真凶：插件级 `inject` 少了 `remote.session`（接管之后"我们成了唯一的调用方"）

1.3.6 加的"把原因摆到面板上"**当天就见效了** —— 用户控制台里出来的是这句：

```
[better-dsh-codex-effort-slider] 会话目录还没就绪：cannot get property "remote.session" without inject
```

这是 **Cordis 的服务注入报错**：服务访问是**跟着调用方 ctx** 走的。

### 根因（三份代码对起来才看得见）

1. `ModelDirectoryResolver.directoryFor()`（`dsh-client-ui-model-selection/lib/client.js:391`）
   给一个**新** binding 建实例时要 `new ModelDirectory(this.ctx.remote.session, …)` ——
   访问 `this.ctx.remote.session` 要求**调用方**声明过它；
2. 官方插件在**插件级** inject 里就声明了：`["commandUi","locale","sessions","slots","remote","remote.session"]`
   （`:1188`，逐字核对过；Resolver 类自己也有 `static inject`，两处都有就是为这件事）；
3. 我们的 inject 只有 `["slots","sessions","modelDirectories"]` —— **少了那两个** ✗。

### 为什么"以前能用、接管之后才坏"（这次的关键）

`directoryFor()` 对每个 binding **缓存**实例：

```js
const existing = live.directories.get(binding);
if (existing !== void 0) return existing;      // 命中就直接返回，**根本不碰 remote.session**
const directory = new ModelDirectory(this.ctx.remote.session, …);   // 只有走到这里才需要注入
```

从前官方那颗席按钮**也在渲染** —— 它先调一次 `directoryFor()` 把实例建出来（它的 ctx 声明齐全），
我们后来的调用只是**命中缓存**，所以一路正常。1.3.2 接管那一格之后**官方组件不再渲染**，
我们成了第一个（也是唯一的）调用方，于是必须自己建实例、必须自己声明那两个服务。
再加上启动顺序的微小差异，它还表现为"时好时坏"（一会儿是"没有可用的 provider"，
一会儿是"会话目录未就绪"）—— 这也解释了 1.3.4 与 1.3.6 两次截图为什么不一样。

### 修了什么

- **一行**：插件级 `inject` 补上 `"remote"` 与 `"remote.session"`（order 与官方一致）；
  两个服务是**必然存在**的（`modelDirectories` 自己就静态依赖它们），所以不会让 fiber 停在 PENDING。
- **测试台补上这条规矩**：假宿主的 `directoryFor()` 现在会像真宿主那样，对"没声明 `remote.session`
  的调用方"抛同一句原话；`setupPicker` 把 `bundle.plugin.inject` 灌给它。
  于是**少声明一个服务，离线套件立刻红** —— 这是 1.3.7 最值钱的那部分（原先它完全测不到）。
- 第 45 节 +4 条：声明里必须有 `remote` / `remote.session`、测试台确实在复刻这条规矩、
  以及"故意少声明时抛的就是真机那句原话"。

总数 **864 → 868**。

---

## 1.3.6 — 面板卡在"会话目录未就绪"：把失败原因摆到台面上 + 空会话要说人话

插件整包回来之后（1.3.5 修掉 BOM），面板变成 **"会话目录未就绪，正在重试…"**、档位 `—`、
等了很久也不动。这一版就是为它：

### 为什么以前查不出原因：我们自己把错误吞了

`resolve()` 里是 `catch (error) { fresh = null; }` —— 宿主的原话（`directoryFor()` 抛的
`ui-model-selection: session "<id>" resolved no scope / no binding`，里面还带着**是哪个 id**）
被静默丢掉，界面上只剩"未就绪"三个字。于是排查只能靠猜，而且猜错方向（先怪目录空、
再怪 provider、再怪插件没加载）。现在：

- 失败原因记进访问器（`reason()`），**每换一条新原因往控制台 `warn` 一次**（同一条不刷屏）；
- 面板在"未就绪"时把这句话**直接摆出来**（复用失败清单那一行样式，超过 96 字截断，悬浮给全文）；
- 按钮的悬浮说明也带上它。

### 顺带把两条"看起来像坏了、其实不是"的状态说清楚

- **`no-session`**：一个会话 id 都没有 —— DSH 的输入区在**"新会话"空白壳**里也会渲染
  （`conversation.composer.bar` 在那种状态下是 session-maybe 作用域，`binding.key` 是 undefined）。
  这时说"正在重试"是误导：没有会话可重试。现在文案是
  **"还没有会话 —— 发一条消息后就能选模型"**（发消息 / 打开已有会话后组件重挂，自动就好）。
- **两条会话 id 来路**：渲染器拼 props 的顺序是
  `{...标准 kit, ...inject 的返回, ...槽注入, ...owner}`（`dsh-client-ui-renderer/lib/client.js:763`），
  而我们以前 `inject: (sessionId) => ({ sessionId })` —— 万一它与 kit 的值不同，就会**把对的盖掉**。
  现在 `inject` 只回一个私有键 `__sessionKey`，访问器拿到 **`[kit 的 sessionId, inject 的 binding.key]`**
  两个候选（前者优先），坏的会**自动轮换**到好的（`resolve()` 里逐个试、成功的钉住）。
  查证过官方实现：`standardProps` 的 `sessionId` 来自 `scopeBinding.key`，而 `SessionEntry` 给 kit 与
  `inject` 的是同一个 binding（`:790-795`），所以正常情况两者相同 —— 这条改动是**冗余保险**，不是主因。

### 测试

新增第 45 节（**11 条**）：三种 id 组合（只有 kit 对 / 只有 inject 对 / 两个都不对）各自的行为、
候选顺序、以及"面板上必须出现宿主原话"。另外**测试台也修了一处失真**：`setupPicker` 以前是把 kit 的
props 直接喂给组件、**从不调用 `inject`**，所以"inject 覆盖 kit"这件事在离线测试里根本看不见 ——
现在它按真渲染器的顺序拼 `{...kit, ...inject(bindingKey)}`（`options.bindingKey` 可单独给）。
总数 **853 → 864**。

---

## 1.3.5 — 把"我们没拿到目录"和"宿主就是没有 provider"分开（顺带查清了这次的真凶）

用户截图：面板终于能看见字了，写的是 **"没有可用的 provider"**、档位 `—`、滑条灰掉。
但这句含糊的话同时对应两种完全不同的处境，而旧版里它们在界面上一模一样：

| 处境 | 谁的问题 | 旧文案 |
| --- | --- | --- |
| `directoryFor(sessionId)` 一直抛 / 目录实例还没解析出来 | **本插件**（会话作用域还没就绪，会自动重试） | 没有可用的 provider |
| 宿主目录 `status: ready`，但 `groups` 是空的 | **宿主**（模型目录就是空的） | 没有可用的 provider |

所以 1.3.5 让**访问器自己报出它走到哪一步**（`access.phase()`：`unresolved` / `loading` /
`empty` / `ready` / `error`），界面照着说人话：

- 空态那句：`unresolved` → "会话目录未就绪，正在重试…"；`empty` → "**宿主没有列出任何 provider**"；
- 空态节点带 `data-phase`（诊断口径可断言，也可以被将来的一键诊断读）；
- `empty` 的悬浮说明直接指向该查的地方："检查 DSH 的模型 / 账号设置（官方菜单此时也是空的）"；
- 按钮的悬浮说明同理（`…（宿主没有列出任何 provider）` / `…（会话目录未就绪，正在重试）`）。

### 顺手查清的事：宿主为什么会"就绪但空"，而且一声不吭

翻的是**装好的官方产物**（`app.asar` 里那几份 `lib/index.js`），不是猜的：

1. 宿主 `buildModelCatalog()`（`dsh-api-session-controller/lib/index.js:500`）只列
   **当前注册的 provider**，并把"0 个模型的组"整个丢掉（`:541` 的
   `.filter(group => group.models.length > 0)`），每个 provider 的异常收进 `failures` 数组；
2. **`deepseek-account` 的 `discoverModels` 在拿不到账号令牌时会静默返回空列表**：
   `dsh-llm-deepseek-account/lib/index.js:49-57` —— `resolveToken` 抛
   `ACCOUNT_SIGN_IN_REQUIRED` 就 `return []`，**不报错**；
3. `resolveToken`（`dsh-deepseek-account-platform/lib/index.js:786`）在这些情况下静默返回
   `undefined`：端点 origin 与该账号推导出的 inference origin 不一致、凭证库里没有那条 grant、
   grant 的 issuer 与自建端点不匹配、或令牌是 `dsh_mock_` 前缀的假令牌。

三者合起来就是"**groups 空 + failures 空 + status ready**"——正好是本插件面板 1.3.3 之后
如实显示的那个状态。**也就是说：这不是渲染/接线问题，宿主那边确实一个 provider 都没列出来**，
官方菜单（`/model`）此刻同样是空的。凭证库里那条 grant 的 issuer 是
`https://platform.deepseek.com`，而"它与当前 inference 端点是否匹配"只有账号服务知道 —— 这属于
DSH 的模型/账号设置，本插件只负责如实转述，不越权代改。

### 测试

第 31 节：把那句含糊的断言换成"**必须说 unresolved**"（文案 + `data-phase`）；
第 43 节：补 `data-phase=empty` + 悬浮说明指向 DSH 设置。总数 **839 → 843**。

### ⚠️ 同一版里的第二个事故（而且是我自己造成的）：`package.json` 被写进了 UTF-8 BOM

现场：用户说"**整个插件效果都没有了**"，重启也不回来，但 `/model` 一切正常。
从插件管理器拿到的那句话是决定性的：

```
{ "name": "better-dsh-codex-effort-slider", "enabled": true, "installed": true,
  "error": { "code": "operation-error",
             "diagnostic": "Unexpected token '\uFEFF', \"\uFEFF{\r\n  \"nam\"... is not valid JSON" },
  "rows": [] }
```

**`rows: []` = 一个条目都没加载**（对照：宿主加载器那 191 个条目里确实没有我们；
客户端那一半自然不会进浏览器，于是"插件效果全没了"）。宿主读 bundle 清单是**直接
`JSON.parse` 文件内容**，而 `JSON.parse` 不吃 BOM。

根因是**我的编辑工具链**：这一版我用
`(Get-Content package.json) -replace … | Set-Content package.json -Encoding UTF8` 改版本号，
而 **Windows PowerShell 5.1 的 `Set-Content -Encoding UTF8` 会写 BOM**（`Out-File` 同理），
`README.md` 一起中招。修法是**按字节剥掉 BOM**（`fs.writeFileSync(f, buf.subarray(3))`），
而不是用同一类命令再写一遍。

新增第 44 节（**10 条**）给这件事上锁：`package.json` 必须无 BOM、且能被 `JSON.parse` 直接吃掉，
`lib/*.js` 与 `cordis.patch.yml` 同样不许带 BOM；另外钉住"宿主侧自检**不读** `package.json`"
（所以那次事故里它照样报"产物就绪"，一点忙都帮不上 —— 这类"工具链静默破坏"必须有断言盯着）。
总数 **843 → 853**。

---

## 1.3.4 — 三条用户实测反馈：流式输出时面板消失 / 浅色主题星尘发黑 / 右缘没对齐输入框

### 1. 「对话还没结束的时候，对话一刷新，面板就没了」

**根因是旧的滚动策略**：面板当时监听全文档的 `scroll`（capture 阶段），规则是"页面在滚就关面板"，
理由是"重定位正是面板乱飘的来源"。但助手流式输出时**聊天区一直在自动滚动** ——
scroll 事件于是不停地到达 document，面板被自己的策略关掉了。

而那条理由其实不成立：面板是 `position:fixed` + **底边锚在触发器顶边**，聊天区滚动根本不动 composer。
**现在改成重定位**（`pickerStore.reposition()`）：滚动/视口变化时按当前几何重算一次，
不关闭；`reposition()` 只在结果真的变了才 `emit()`。
两处配套细节：

- **触发器几何为 0 时保持原位**：助手在跑的时候宿主会给 composer 的控件行 `hidden`，
  那时 `getBoundingClientRect()` 全 0 —— 拿零尺寸去定位会把面板甩飞，所以 `liveRectOf()`
  直接返回 null、面板原地不动（也不消失）。
- **位置放进 state**（这次一起修的隐藏 bug）：位置以前是渲染时 `pickerStore.position()` 现读的，
  而重定位只改 store、不改 state —— 订阅回调里 `setOpen(同一个布尔)` 被 React **bail out**，
  于是**一次渲染都不发生**，面板看起来"纹丝不动"（跟着锚点走的期望直接落空）。
  现在 `pos` 也是 state、一起订阅；位置没变时 store 原样返回旧对象 → `setPos` 照样 bail out，
  不会有多余渲染。这条是探针跑出来的：`reposition()` 返回 `true` 而界面纹丝不动。

### 2. 「浅色模式的星尘颜色不对，深浅主题下星尘都要是浅色」

星尘永远飘在**填充层**上（蓝→紫，那套颜色本身就是写死的、不随主题变），
而旧写法是 `background:var(--dsw-alias-label-primary,#eaf0ff)` ——
`label-primary` 在**浅色主题下是近黑色**，于是浅色模式里星尘成了深色小点、糊在紫底上几乎看不见。
现在写死浅色 `#eaf0ff` + 一圈固定微光（`STAR_COLOR` / `STAR_GLOW`）。
与 1.2.0 那半边的 `.ces-star__dot`（本来就是 `#fff`）口径一致，也和 `.cxp-knob` 的固定白同一条纪律：
**"必须保持是亮的"的东西不跟主题令牌走。**

### 3. 「面板的右边要对齐输入框的右边」

面板以前是**左缘贴触发器**，看起来相对输入框往右伸出半截。现在算的是
**右缘贴 composer 卡片右缘**（`left = card.right − 272`），三级回退：
卡片右缘 → 触发器右缘 → 触发器左缘 + 面板宽；结果照旧夹进视口留白内。
卡片的认法沿用 1.2.0 那条锚点：从触发器往上找 `[data-composer-card]`。

### 测试

第 35 节从 25 条扩到 **34 条**：滚动/缩放**不再关闭面板**、重定位真的跟着锚点走、
触发器 `rect` 全 0 时保持原位、Esc 逐层退避后监听器摘干净；
第 38 节加了 4 条"星尘是固定浅色"的断言（与旋钮那条同一节：**必须保持亮的东西不跟主题走**）。
总数 **823 → 839**。

---

## 1.3.3 — 真机事故复盘：接管之后"目录为空"没人治，面板一片空白

**现场**（1.3.2 装好后重启 DSH，用户截图）：输入区只剩一颗按钮、写着"模型"；点开面板，
"模型"标题下面**一个字都没有**；推理等级显示 `—`、滑条灰掉。用户的原话是"重启完用不了了"。

### 三件事叠在一起（缺一条都不会这么难查）

1. **目录是空的**（一个 provider 都没列出来）。宿主那份 `buildModelCatalog()` 只列
   **当前已注册的 LLM provider**（`ctx.llm.listProviders()`），DSH 刚起来时 provider 可能还没注册完
   → 它会返回一个**合法的空目录**；而那个结果**会被缓存**（`ModelCatalogDirectory.load()`
   见到 `status === "ready"` 直接短路返回缓存值，不再问宿主）。
2. **那句"没有可用的 provider / 正在读取…"被视口裁掉了**：`viewportHeightFor` 当时给的是
   `max(44, 30 + 0×41) = 44px`，而 `.cxp-empty` 要 48px —— `.cxp-viewport` 的
   `overflow:hidden` 把它**整句裁掉**。于是"目录空/失败"在界面上长得跟"面板坏了"一模一样。
3. **没人重试**：1.3.2 之前官方那颗席按钮也在渲染，它至少是另一个"再 load 一次"的入口
   （它的组件里会调 `props.load()`）；**接管之后我们是唯一的读取方** ——
   启动期那一次失败/空目录就永远停在那儿了。这是我们接管那一格时**没有一并接过来的责任**。

### 修了什么

- **提示/失败原因看得见**：空目录、加载中、逐 provider 的失败都渲染出来，
  并且 `viewportHeightFor` 把这些块的高度算进去（`EMPTY_H` / `FAILURE_H`，
  与 `.cxp-empty` / `.cxp-failure` 的 CSS 实算对齐）。二级页"无匹配模型"那句同样修了
  （以前只给 80px，那句 48px 的提示也被裁）。
- **逐 provider 的失败清单**：官方菜单会把 `failures` 列成
  `"{name} 加载失败：{message}"`（`warning.groupLoad`），我们以前**整份丢掉** ——
  接管那一格之后这份提示就归我们了。现在按同样的文案渲染（最多 4 条），
  悬浮给出完整 message。
- **load 失败会自愈**：`kickLoad` 失败（或 load 完 store 还不可用）→ 按
  `RETRY_DELAYS`（60ms→3s）退避重试，退避用尽后由 1.5s 的心跳兜底继续试。
  ⚠️ 只治"**目录根本没到**"（idle/loading/error）：`status === "ready"` 时继续重拉会
  变成 **60ms 一轮的活锁**（`load()` 每次都成功返回、store 却依然空，退避计数器还被重置）——
  这一条是写测试时真的把进程跑死才发现的（`needsLoadRetry()` 就是为它加的）。
- **"就绪但空"主动刷一次全局目录**：借官方 resolver 上的实例字段
  `ctx.modelDirectories.catalog.refresh()`（`invalidate() + load()`）——
  **8 秒冷却、最多 3 次**，全程 typeof/try 兜住（借的是内部字段，官方改了就静默退回只显示空目录，
  绝不抛给渲染层）。这是唯一能治"缓存住的空目录"的手段：光调 `load()` 会被短路。
- **按钮文案如实**：目录还没到时显示"正在加载模型…"（对齐官方的 `trigger.loading`），
  不再和"目录空"共用"模型"两个字 —— 真机排查时这两态长得一样是最坑的。

### 测试

新增第 43 节（**17 条**）：空目录的提示**真的落在视口里**（断言视口高度 ≥ 小节 + 提示、
文案是"没有可用的 provider"）、`load` 失败一次后**自愈**（按钮回到模型名、`loads ≥ 2`）、
"就绪但空"→ 调了 `catalog.refresh()` 且**冷却期内不重复刷**、失败清单的文案与 title。
另把第 30 节那条"搜不到时高度 80"改成"要装得下 48px 的提示"（**80 → 128**，旧值本身就是在
钉住那个裁切 bug）。测试台的 `createFakeHost` 补了 `coldDirectory` / `loadFailures` /
`catalog.refresh` 三个能力，否则"启动期空目录 → 自愈"这条链在离线测试里根本复现不出来。
总数 **806 → 823**。

---

## 1.3.2 — 接管官方那颗模型席按钮（`priority: -1` 遮蔽）

1.3.0/1.3.1 的自建浮层是"在工具行**新增**一颗按钮"，于是输入区里并排两颗一模一样的
`模型名 · 档位名 ⌄`：官方那颗 + 我们那颗。这一版把官方那颗**接管**掉，只剩一颗。

### 机制：single 槽 + priority 更低者胜（不是改 DOM）

官方那颗席按钮注册在槽位 **`conversation.input.model`**，那是一个 **`single` 槽**，
官方注册时**没有写 `priority`**（= 0）：

```js
// @deepseek-ai/dsh-client-ui-model-selection/lib/client.js:1248
scope.slots.register({ name: "conversation.input.model", locale: NS, inject: (sessionId) => {...} }, ModelSelect)
```

槽位内核（`@deepseek-ai/dsh-client-ui-slots`）对 single 槽的规则是：

```js
// register()：同 priority 撞了 → 抛错，而报错文案本身就是给的解法
`single slot "…" already has a registration ${occupantHint(occupant)}`
// occupantHint: "… — register at a different priority to shadow it (lowest renders)"
```

而 `entriesOfSlot()` 按 priority 升序取每格**第一个**非 abdicated 条目 —— 所以
**最低者渲染**。我们用 `priority: -1` 注册同一格，官方那颗就**整个不渲染**了。

这不是钻空子：实时槽位目录给这一格标的 `replaceRisk` 就是 **`shadows-shipped-ui`**
（官方知道、允许，只是标了风险）。而且我们**没有碰官方 DOM**：没藏、没删、没改 class，
账本里官方那条还在（它的 effect 归官方管），只是不再被渲染。

### 随之接过来的两条 owner 语义

接管一颗按钮 = 接它的契约。官方那颗原著有的两样，现在都接上了：

| owner 给的 | 官方那颗怎么用 | 现在怎么用 |
| --- | --- | --- |
| `locked`（owner prop） | `disabled` | `disabled` + `data-locked` + `aria-disabled`，`title` 里写明"当前不可切换"，点击直接返回、不开面板 |
| `--dsh-composer-model-text-display` / `--dsh-composer-model-icon-display` | 窄行里把文字换成图标 | 同一套变量（CSS 里读），另自绘一颗"层叠"图标 `ICON_MODEL` |

### 退路：拿不到那一格就退回老位置（fail-open）

`ctx.slots.inject` 的语义是"**等**那个槽被声明"，没声明就永远不回调（不是抛错），
所以三种时序都要处理：

1. 官方席先声明 → 直接接管（正常情况：三个槽由同一条父条目一起声明）；
2. 工具行先声明 → 先按老样子挂上去，官方席随后声明时**撤掉工具行那条**再接管
   （两个回调在同一批里同步执行，中间没有绘制，所以看不到"闪一下"）；
3. 官方席始终没有 / 注册抛错（被改成 list 槽、或被同优先级占了）→ 工具行那条就是最终落点。

最差也只是回到"两颗按钮"的老样子，**绝不会两边都没有**。

### 顺带修的两处交互

- **`findOpenMenu` 不再"抓到第一颗展开的席就收手"**：1.3.2 起自建触发器也带
  `aria-haspopup="menu"` + 展开时 `aria-expanded="true"`，要是它被先抓到，
  官方菜单那条路（默认关闭）会在那一帧整帧停手。现在跳过**没有 `aria-controls` 的按钮**
  （官方那颗一定带 `${id}-menu`），继续往后找。
- **两条路二选一**：`ENABLE_OFFICIAL_MENU_SLIDER = true` 时**提前 return**，不再接管官方席 ——
  否则"回到官方菜单注入"那条路会因为入口被我们拿掉而永远打不开（滑条长在菜单里）。

### 代价（写进 README 的已知限制）

官方菜单（模型列表 / 档位列表 / 键盘导航 / aria）**没有入口了** —— 那颗席按钮就是它唯一的入口。
模型切换仍在两条路上：本插件的面板，以及 **`/model` 命令**（官方另一套 `popupSelect` UI，不受影响）。
想要"官方菜单 + 里面长滑条"，把 `ENABLE_OFFICIAL_MENU_SLIDER` 改成 `true`。

### 测试

新增第 42 节（**30 条**）：遮蔽生效（先摆一条 priority 0 的"官方席"，再断言这一格
实际渲染的是我们这条、且官方那条仍在账本里）、三种时序的退路（槽不存在 / 槽姗姗来迟后
接管并撤掉工具行那条 / 注册抛错后退回）、`locked` 三态（`disabled` / `aria-disabled` /
点了不开面板）、紧凑态（图标节点在 + 样式表确实读那两个变量）。
另外第 11 节的接线断言 +5（落点从 `input.right` 变成 `input.model`、priority 为 −1、
接管成功时不再往 `input.right` 注册、开关打开时提前 return），**总数 771 → 806**。
测试台（`test/harness.mjs`）的假槽位系统也补齐了真内核的三条行为：**槽没声明就不能注册**、
`inject` **只等不抛**、**single 槽同优先级撞了会抛错**（"换个优先级去遮蔽它"）——
否则"接管"这件事在离线测试里根本测不出来。

---

## 1.3.1 — 二级页模型列表按「新发布 → 旧发布」排序

二级页那一屏模型列表以前**原样照着宿主目录的顺序**列（`groups[].models[]`），于是形如
`gpt-4` → `gpt-4.1` → … → `gpt-6-astra` 的清单里，**最新发布的那几个反而沉在最下面**。
现在统一按"新 → 旧"排。

### 依据：宿主目录里**没有**发布日期字段

不是没找到，是没有。`session/modelCatalog` 的产物 schema
（`@deepseek-ai/dsh-api-session-controller/lib/typert.host.js`，逐字看过）里，模型条目只有：

```ts
{
  id: string,
  name: string,
  description?: string,
  reasoning?: { efforts: { id: string, name: string, description?: string }[], defaultEffort?: string },
}
```

没有 `releasedAt` / `createdAt` / `version` 之类。所以"新旧"只能从名字里本来就有的两个信号算：

| 信号 | 认什么 | 例子 |
| --- | --- | --- |
| 版本号 | 第一个数字串；**id 里没有就看显示名** | `gpt-6-astra` → 6、`gpt-5.6-sol` → 5.6、`deepseek-v41-flash` → 41、`deepseek-flash` 的显示名 `DeepSeek-V41-Flash` → 41 |
| 日期 | `2026-01-13` / `20260113` / `2026-01` | `gpt-4o-2024-05-13` |

"id 里没有就看显示名"这条不是凑数：真目录里 DeepSeek 账号 provider 的模型就是
`{ id: "deepseek-flash", name: "DeepSeek-V41-Flash" }` 和 `{ id: "deepseek-v4-pro" }`
（`@deepseek-ai/dsh-llm-deepseek` 的 `DEFAULT_MODELS`）—— 只看 id 的话，版本更新的
`deepseek-flash` 会被判成"认不出版本"而沉到底。

### 规则（四条，全部确定性）

1. **版本号降序**，逐段按**数字**比（`6` > `5.6` > `5`；`5.10` > `5.9`，不是字典序）；
2. 同版本：**别名在前、它的快照版在后** —— `gpt-6-astra` 指最新，`gpt-6-astra-2026-01-13`
   是钉住的旧版（快照版按 `<别的模型 id 或 name>-<日期>` 认出来）。只按日期排会把快照版顶到
   别名前面，恰好排反；
3. 同为快照：日期**新 → 旧**（`gpt-4o-2024-11-20` 排在 `gpt-4o-2024-05-13` 前面）；
4. 认不出版本号的**沉底**，内部保持宿主原顺序；排序键完全相同的也保持宿主原顺序（稳定排序）。

排序在 `readCatalog` 里做**一次**（纯函数 `sortModelsNewestFirst`：不改入参、脏数据不抛错），
所以二级页、搜索过滤结果、以及任何读这份目录的地方拿到的都是同一个顺序。

### 代价与边界（已知取舍）

- `o3-mini` / `o1-pro` 这类"前缀不是版本号"的家族，只能按它们自己的数字排（`4` > `3` > `1`），
  于是落在 `gpt-4o` 之后 —— **名字里看不出新旧的一律沉底，不猜**；
- 官方菜单那一屏的模型列表仍是官方的顺序：插件只往上加徽标，不动官方 React 渲染的 DOM
  （动了会和官方重渲染打架）。

### 测试

新增第 41 节（**20 条**断言）：两个信号的解析、"别名 + 快照版"的定序、稳定排序与"不改入参"、
以及**照真目录形状**的两组集成断言（`deepseek-flash` 的 V41 在 `deepseek-v4-pro` 之前；
`gpt-5.5 → gpt-4o → gpt-4o-2024-11-20 → gpt-4o-2024-05-13`）。

另外把第 27 / 31 / 31b / 31c 节里**按下标取模型行**的地方改成**按名字取**（`modelRowByName`）：
列表顺序变了以后，那些用例真正想验证的是"**哪一行**的行为"（灰显、勾选、点它写什么），
不是"它排第几"；按下标写会让排序规则一改就整片红，而那种红并不指向真问题。
断言总数 **751 → 771**。

---

## 1.3.0 — 按 `code.html` 复刻自建界面

参考实现 `code.html` 那份界面（自建模型菜单 + 两级面板 + 推理等级滑条 + 档位弹层）**原样落地**，
成为插件里的第二个界面：`lib/client.picker.js`。官方菜单那一行那条控件**保留在仓库里**，
但**默认关闭**（见下面"收尾"一节的总开关）。

### 新增：自建浮层（`lib/client.picker.js`）

- **收起态一颗按钮**：`模型名 · 档位名 ⌄`（档位名按能量着色，Off 档保持主题灰）。
  新增在 `conversation.input.right`（**不替换**官方那颗模型席按钮）。
- **无档位模型也能选中**（选模型与配档位解耦）：二级页里标「不支持」的那些行以前是**点不动**的
  （`pickModel` 见到 `levels.length === 0` 直接 return）。现在点它**只切模型**，滑条卡片转禁用态、
  档位名显示 `—`；那次写入**只带 provider/model**，`reasoningEffort` 键**整个不出现**
  （缺席 = "对档位没有意见"；显式 null = "显式清除" —— 宿主侧是两回事）。
  契约不是猜的：官方产物 `dsh-client-ui-model-selection` 的 `select()` 用的是
  `...selection.reasoningEffort === void 0 ? {} : { reasoningEffort: … }` 条件展开，
  第 12 节新增了产物对照断言钉住这个形状（若官方哪天改成传 null，断言会红）。
  `viewportHeightFor` / 二级页行高 / 徽标文案（仍「不支持」）与灰显样式全部不动。
  同时 `pickModel` 换模型前会清干净**旧模型待落地的档位写入**（`timer` / `queued` / `optimisticId`
  三个字段）—— 否则它的去抖窗口会在切换之后才落地，把新模型写回旧档位；
  而 `optimisticId` 在切到无档位模型后永远等不到"宿主追上"（`catalog.level` 变 null），
  不清就是一次悬挂状态。这条有专门的回归钉（第 31c 节）。
- **点开是两级面板**，落在 `conversation.input.overlay`（官方插槽目录原话：
  *Floating entries rendered inside the resident composer card*）—— 那里不会被 composer 卡片裁掉，
  所以面板能像官方菜单那样浮在卡片上方：
  - **一级页**：provider 行，右侧显示该 provider 当前选中的模型名（一级页就能确认切换生效）
  - **二级页**：搜索框 + 模型列表，每行一颗**档位徽标**（`8 档 / 7 档 / 5 档 / 不支持`），
    悬浮给出完整档位名清单
  - **常驻**：推理等级卡片（标题 + 当前档位名 + 滑条）
  - **档位弹层**：每行显示档位名 + **灰色原始 API 取值**（`xhigh` 之类，发送请求用的就是它）
- **双页 carousel**：`page1 0 → -100%` 与 `page2 +100% → 0` 同步位移，两页同一原点保证边界贴合；
  换页那一帧把列表滚动位置稳住（浏览器可能替我们滚：focus / 锚定）。
- **滑条观感**：轨道 20px / 旋钮 28px / 端头半径 10px；填充与本插件 1.x 用同一套位置函数
  （蓝 → 靛 → 紫，能量自位置 1/3 起通电）；星云层 + 22 颗星尘（确定性伪随机、8 条泳道、
  黄金比相位）；刻度点 4px；最高档 solo（只留当前位置那一个刻度）。
- **交互**：按下 = 点哪去哪；拖动要越过 **1/3 档距**才换档；快慢两档滑动（320/200ms 迟滞）；
  写回是**停顿去抖 + 同档去重**（拖动期间一次都不打宿主，停手或松手才落地）；
  Esc / 外点从里到外退避（档位弹层 → 二级页 → 面板）。

### 与参考实现的四处差异（都有意为之）

1. **颜色走 DSH 令牌**：参考实现是写死深色的 demo，真插件必须浅色/深色都跟随；
   写死的只有能量色三个（`#3f8cff` / `#7c6cf6` / `#a855f7`，观感本体）。
2. **能力清单是活数据**：读目录快照 `groups[].models[].reasoning.efforts`，不再内置静态清单。
3. **写回走官方 `directory.select()`**：保留 1.1.0 起的去抖/去重语义。
4. **视口高度用算式而不是 DOM 测量**：离线测试台没有布局引擎，测量会得到 0（面板会"看不见"）；
   真浏览器里两者等价。

### 工程

- 客户端变成**两个文件**：`lib/client.js`（接线 + 官方菜单那条控件）在工厂里用
  `require.async("./client.picker.js")` 取自建浮层。
  > 这里踩过一个坑：客户端的模块表（`@deepseek-ai/dsh-client-modules`）是**按包名**建表的，
  > 同步 `require("包名/子路径")` 会直接抛 "missed the module table"。正规做法是**包内动态 chunk**：
  > 文件名必须匹配宿主的 `client.*.js` 规则，宿主按 `/plugins/<包名>/client.picker.js?rev=…`
  > 路由 serve（带 revision 与 HMR 失效）。取不到时**只有自建浮层消失**，官方菜单那条路照常。
- **chunk 必须自注册（真机第二次踩坑）**：第一版 chunk 写成了**裸 ESM**（`export { … }` 结尾），
  而宿主对 chunk 的响应体**只做拼接、不包壳**（`buildComboScript` 直接 `source += …`）——
  于是 `export` 在脚本标签里直接语法错、工厂从未注册，`require.async` 永远取不到，
  用户看到的就是"**入口按钮根本不出现、控制台还很安静**"。
  现在：源码留在 `lib/client.picker.src.js`，`node build/pack-picker.mjs` 把它包成
  **自注册**的 `lib/client.picker.js`（`id` = 包名、`chunk` = 文件名、工厂 `return` 出导出），
  `pretest` / `prepack` 自动跑这一步，第 32 节断言按**真宿主的方式**加载它。
- 宿主半边（`lib/index.js`）的自检扩成**两份产物分开报**：少了 chunk 只报
  "自建面板不会出现"，不掩盖 `client.js` 的问题。
- 测试台补上 `lib/client.picker.js` 的加载（**真文件、真代码**，且走它自己的注册路径，
  不给面板另写替身），并把 `document` / `window` 按平台全局注入给模块 —— 少了这一层，
  面板里所有"只在浏览器里跑"的副作用（Esc、外点、滚动稳定化）都会被静默跳过。
- 定位降级：拿不到 `window` 时面板照常渲染（只是不跟随重定位），第 33 节盯着这条。
- 测试从 **465 项增加到 751 项**：新增第 27–31 节（浮层结构 / 滑条与写回 / 档位弹层与 Esc /
  双页舞台与视口高度 / 禁用态与 fail-open / provider 与模型切换的回归），
  以及第 32–36 节（**chunk 加载契约** / 样式真的进了文档 / **触发器与面板拆分挂载 + 定位冻结**）。

### 收尾：五处

1. **面板内部的滚动不再关掉面板**。`onScroll` 挂在 document 的 capture 阶段，模型列表
   （`.cxp-list`）一滚，事件同样到达 document —— 于是"滚一下列表"把面板自己关了。
   现在先判 `rootRef.current.contains(event.target)`，目标在面板内就放行。
2. **幂等守卫的 cleanup 加上 `if (!claimed) return`**。被拒的那个实例（`claimed === false`）
   在卸载时会把守卫标志清掉，而它属于活着的那个实例 —— 清了以后下一个实例会以为自己拿到了
   所有权，于是又冒出第二颗 trigger / 第二个面板。
3. **面板定位改成「底边锚定」**（这一条**推翻了**本版中途的一个改动，见下）。
   中途我先把 `panelH` 估算从 360 调到 460 —— 那是在**错的方向**上打补丁：顶边锚定
   （`top = rect.top - panelH - gap`）必须先知道面板高度才能定落点，而高度由内容决定
   （一级页 ≈216px、二级页最多 ≈446px），于是估算两头都错：
   - 估大了（360/460）：一级页实际才 216 → 底边**悬空**一两百 px，不紧贴触发器
   - 内容变高（切二级页）：`top` 冻结 → 面板朝**下**长，正长错方向，越切越长

   现在 `computePanelPos` 返回 `{ left, bottom, maxH }`：底边永远贴在触发器**顶边上方**
   `PANEL_GAP` 处，`panelH` 估算与上下翻转逻辑**整个删除**。内容变高时向上延伸、底边纹丝不动
   —— 这正是 `position:fixed` + `bottom` 的原生行为，**根本不需要知道面板多高**。
   配套两处 CSS：`.cxp-root` 加 `overflow:auto`（极矮窗口时面板内部滚动、不顶出屏幕）、
   `.cxp-panel` 的 `transform-origin` 跟锚定边统一成 `bottom right`。
   代价：不再跟 `code.html` 的 `openMenu` 一样"落在下方"，取"不悬空、不朝下长"。
4. **视口尺寸变化 → 直接关闭面板**（与滚动同一条策略，`win.resize`）。之前的定位是"重算坐标"，
   那正是"面板乱飘"的来源之一；现在统一成"关闭，不重定位"。
5. **官方菜单那条控件（`.ces-` 注入路径）默认关闭**：新增总开关 `ENABLE_OFFICIAL_MENU_SLIDER = false`
   包住 `ENTRY_ID` 那条注册。主入口是自建浮层，两套 UI 同时挂在同一个输入区里会互相干扰。
   **组件、纯函数、第 2–26 节断言全部保留**，把它改回 `true` 就恢复 —— 测试也因此不再依赖
   注册顺序，改成直接挂组件本身（测的一直是它的行为）。

第 3 条与第 1/4 条的断言都做过**反向验证**（故意改回错误实现，确认变成 FAIL 再恢复）：
回退成顶边锚定 → 9 条红（含"二级页变高 → 底边不动"这条回归钉）；回退两处 CSS 配套 → 2 条红。

### 逐行审核后的修复（八条，含测试盲区）

一次逐行审核在**默认生效**的自建面板那条路上找出这些 BUG —— 全部先复现、再修、再反向验证
（把修复改回错误实现，确认断言变红）。共同教训：**694 项全绿也可能漏掉它们**，因为旧断言只覆盖了
"正档位点起拖""星尘有 22 个子节点""标记是非空字符串"这类**形状**。

1. **滑条死区永不释放（最严重）**。`dragRef` 不保存按下点坐标，解锁条件只有
   `judged === drag.index`；而 `judged` 随 `u` 单调递增 —— 按下点落在"冲突带"
   （`u ∈ (n+1/3, n+1/2)`，约占轨道 **1/6**）时，**向右拖永远回不到** `drag.index`，
   于是整段右拖失效、松手还把旧档位写回宿主。
   真机复现：按 u=0.40 → 右拖到 u=2.40 仍停在 Off，松手写回 `["off"]`；对照按 u=0 则正常跟手。
   修法：`dragRef` 记 `u0`，解锁条件补 `|| Math.abs(u - drag.u0) >= THIRD`
   （1.2.0 那半边 `client.js` 保留的正是这条逃逸条件）。
2. **星空层没有宽度 → 22 颗星永远不可见**。`.cxp-stars` 是
   `position:absolute; inset:0 auto 0 0; overflow:hidden`，而子节点全是 `left:100%` 的
   absolute → shrink-to-fit 宽度 **0**，星全被裁掉。真机复现：`style = {}`。
   修法：补 `style: { width: knobLeft }`（与填充层同宽 = 星尘从当前档位点向右横穿）。
3. **`PICKER_STYLE_MARKER` 是 `"undefined/picker"`**：它用了声明在**后面**的 `PACKAGE_ID`
   （同 `var`，hoisting 后 `undefined`）。今天不炸（仍是唯一字符串，去重照常），但丢了包命名空间：
   万一有第二张同标记的样式表，`installStyles` 会复用它、`.cxp-*` 再也注入不进去。
   修法：`PACKAGE_ID` 提到最前；断言从"非空字符串"改成**精确值**。
4. **快/慢档过渡在自建面板里是死代码**：渲染了 `data-slide`，但全仓库**没有**
   `.cxp[data-slide='slow']` 规则（只有默认关闭的 `.ces-` 那一半有），于是
   `noteStep`/`slideSlow`/`SLOW_*` 那一整套只是白白触发重渲染。修法：补上那条规则。
5. **目录读路径不再重新解析 → 界面冻在旧实例上**。`getSnapshot`/`subscribe` 只在
   `directory === null` 时才 `resolve()`，而写路径每次都解析 —— 与注释宣称的
   "每次读写都重新解析"不符。宿主重建 `ModelDirectory`（父子会话换 binding、作用域重建）后
   旧实例已 dispose、**再也不会推送**，界面静默冻在旧档位表上而写却进了新实例。
   修法三条：读路径每次复查（`resolve()` 自带短路，代价只是一次同步查表）；
   `subscribe` 时起**低频心跳**（1.5s，实例没变就是空操作、不 notify）；
   面板打开时调 `access.refresh()`（用户真正要看数据的时刻）。
   心跳定时器带 `unref` 兼容处理 —— 它是永久重复的，在 Node 下会让测试进程退不出去
   （这条也是实跑时踩出来的）。
6. **面板高度算少，一级页 provider 行被裁**：`rowH` 是拍出来的 38，而 `.cxp-row` 实际是
   `10+10 + 14×1.5 = 41`；一级页又没有滚动容器，末行被 `overflow:hidden` 裁掉且滚不回来。
   修法：行高改成**按 CSS 实算**的常量（并把 `.cxp-list` 的 `max-height` 提成共用常量，
   CSS 与算式不再脱节），第 30 节加了一条"从样式表实算行高 → 与算式对照"的断言。
7. **滚动/缩放关面板时 `popOpen` 没复位**：组件只是 `return null` 并没卸载，下次打开会按
   **旧坐标**冒出陈旧弹层，而第一次点「更多」反而把它关掉（Esc 与外点两条路径本来就有复位）。
   修法：抽一个 `dismiss()`（收弹层 + 关面板），两条路径都走它。
8. **（未改，待确认）`valueColorFor` 与 `fillBackgroundFor` 的色带不一致**：前者是
   `蓝→紫→靛`、后者是 `蓝→靛→紫`，同一个 pct 给出不同颜色；1.2.0 那半边是**单段**
   `蓝→COLOR_TEXT_VIOLET`，注释写明"文字不能像填充那样收到深紫，另给一个亮端"。
   注意 picker 这三个色**感知亮度几乎相同**（130.1/128.3/128.5，是"等亮度色相环"），
   所以"最高档变暗"不成立、"文字与填充不同色"成立；而测试里那条断言写着
   「与 1.x 的 high 档同一个值」，说明当初有意校准过 —— 改它会动视觉，留待拍板。

测试从 **694 项增加到 726 项**：新增第 37 节（死区对照 + 冲突带右拖 / 星空宽度 / 标记精确值 /
slow 规则 / 心跳换实例 + 打开复查 / 陈旧弹层），并加固第 30 节（算式与 CSS 实算对照）。
审核指出的盲区一并补上：`[17b]` 的冲突带用例照搬到了面板上；星空不再只数子节点、还查宽度；
标记不再只查"非空"、还查内容；新增"目录实例被宿主换掉"的回归用例。
（同一轮后续又加了第 38–40 节：主题一致性 + 多会话归属 —— 最终 **751 项**。）

### 删掉两个全局幂等守卫：一次误诊的清算

**被删掉的是** `PICKER_TRIGGER_LIVE` / `PICKER_SURFACE_LIVE` 两个模块级布尔（1.3.0 中途加的），
以及它们带来的 `claimed` state、cleanup 与「渲染里早返回 null」。

**误诊链**：当初真机上出现"两颗按钮"，当时的判断是"`conversation.input.right` 插槽被宿主双实例化"，
于是用全局布尔做幂等。**但真因是两条条目并存** —— `ENTRY_ID`（官方菜单那条控件，order 40）与
新 trigger（order 30）**都挂在 `conversation.input.right`**。方案 B 把前者关掉
（`ENABLE_OFFICIAL_MENU_SLIDER = false`）之后，双按钮的根因就已经除了，此后真机再没出现过。
**守卫在防一个不存在的幽灵，代价却是实打实的**：

| 现象 | 成因 |
| --- | --- |
| 同工作区两个会话只有一颗按钮 | claim 被**挂载时序**占先的那个拿走 |
| 哪个会话有按钮是随机的 | 竞态窗口胜负取决于切换那一刻的渲染/卸载交错 |
| **新建对话一定没有按钮** | 新建时旧会话必然存活到新实例渲染之后 → 新实例固化 `claimed = false` |
| 每个工作区恰好一颗 | 工作区切换间隙 flag 被释放，新工作区第一颗挂载的重新赢 |

claim 是在**渲染阶段**拿的，而它本意要防的是"同一插槽双实例化"——两者根本不是一回事。
真正被牺牲掉的是宿主插槽系统的正常契约：**每个会话各有一颗按钮**（官方的模型席按钮就是这么工作的）。

**修复**：开合状态改为**按会话归属** —— `pickerStore` 记 `owner = sessionId`，
`isOpenFor(sessionId)` 取代全局 `isOpen()`；trigger 点击时"只有**自己的**面板开着才收起，
否则打开自己的（把 owner 抢过来）"；trigger 与 surface 的 `open` 都按自己的 sessionId 判断。
顺带修掉一个**跨会话状态泄漏**：原来 A 开着面板切到 B，B 也看得到那块面板。

**新语义**（有意选择，已写进注释）：面板属于打开它的会话 —— A 开着面板切走，面板随 A 消失；
**切回 A 时面板还在**（归属存在 store 里，不随组件卸载丢失）。真机若觉得突兀，
改成"卸载即 close"只需一行，测试同步改。

`setTrigger(node)` 现在忽略 `null`：卸载中的实例会拿 null 进来，照单全收会把**还活着的**
那个实例的引用清掉（外点判定随之失效）。

**测试**（第 39/40 节，+18 项）：`setupMultiSession` 同树挂两组 (trigger+surface)，
第一条断言就是**区分性**的 —— 旧守卫下第二颗渲染成 null，这条必 FAIL。
反向验证：模拟"第二个会话渲染 null" → `FAIL [39] 两个会话各有一颗按钮（期望 2，实际 1）`；
把 `isOpenFor` 退回 `isOpen()` → 4 条红；trigger 点击退回 `isOpen()` → 4 条红。

顺带修了测试台三处**保真度缺陷**（都是多节点场景才暴露的）：
`render()` 原来只摘掉**最后一个**渲染节点（多节点会逐轮残留累积）；
`find/findAll` 只从 `tree`（最后一个节点）往下找、**看不到兄弟节点**；
`unmount()` 只跑 effect 清理、不摘 DOM（重挂会与残留叠加）。

顺带修了测试台的两个缺陷（都属"让断言测不到东西"的类型）：
- 假 `window.addEventListener` 原本是空函数，于是"注册在 window 上的行为"（第 4 条的 resize 策略）
  在测试里**根本注册不上**，被 `typeof` 守卫静默跳过。现在记录监听器并支持 `dispatch`。
- chunk 拿到的 `platform.window` 原本是个只带 `__ModuleLoader__` 的空壳，同上。
- 断言失败信息里的 `JSON.stringify` 遇到假 DOM 的循环引用会抛异常，导致**测试中途崩在那一行**、
  后面的断言全不跑（明明该看到一条 FAIL 却只看到 crash）。现在有安全的 `show()` 格式化。

### 已知未验证

- 面板的**真机观感**（浮层位置、深浅主题、粒子动效）要在 DSH Desktop 里用眼睛确认；
  离线断言覆盖的是结构、数据流、状态机、写回与加载契约，不是像素。
- 这一版修掉的"入口不出现"是**加载契约**层面的问题；修好之后我在真机上仍然没有目视确认过——
  如果重启后入口出现了但样子不对，那是观感问题（另说），不是加载问题。

---

## 1.2.0

把参考实现（`code.html` 那份原型的最终态）里**能落到真宿主上的部分**合并进来。
原型是自建菜单的静态页，真插件只改造官方菜单里的「推理等级」那一行，所以逐条对照后有取舍：
**能移植的都落了地，不能移植的在 [MODIFICATIONS.md](MODIFICATIONS.md) 第七节「v1.2.0 的移植对照」里逐条写明了原因**。

### 新增：官方菜单里的三处只读注记（都只 append，不改官方任何文字）

- **模型列表每一行一颗档位徽标**：`4 档 / 8 档 / 不支持`，直接写在模型名旁边（官方 `.optionCopy` 内），
  悬浮给出完整档位名清单、不支持时明示"该模型不支持推理等级"。数据来自**目录快照**
  （`groups[].models[].reasoning.efforts`），目录没列到的已知家族退到本地能力清单，两边都不认识就不写（不瞎标）。
- **根面板「模型」那一行的 provider 归属标签**：`deepseek` / `openai` 一小段灰字跟在箭头右侧，
  一级页就能确认 provider 切换生效（真宿主里没有"provider 行"，所以落点是这一行）。
- **档位列表每一行右侧的原始 API 取值**：`xhigh`、`none` 这种——**发送请求时用的就是它**，
  界面上一直缺这一格信息。

### 新增：档位字典与三级检测（参考实现的数据层形状）

- `LV` 字典（9 键：`off/none/minimal/low/medium/high/xhigh/max/ultra`）+ `tiers()` 校验：
  目录里的档位 id 认不出就**返回 null 而不是抛错**（"一条脏数据最多禁用滑条，不能瘫痪整个 UI"）。
- `resolveModel()` 三级检测：精确命中 → 最长前缀（快照 id `gpt-6-astra-2026-01-13` 继承 `gpt-6-astra`）
  → null。**只作为目录查不到时的兜底**：真宿主的能力清单是活数据，客户端不重建它。
- 修掉参考实现里 `resolveModel(DEF_ALIASES[id] || id)` 的自环（别名表没命中时会拿同一个 id 再进来一次 → 爆栈）。

### 修复与加固

- **禁用态 = 渲染函数的完整投影**：`disabled` 每帧从最新快照重算，投影到 `data-disabled` 上
  （CSS 灰掉 + 不吃指针），并同步 `aria-disabled`。不做增量 patch、不存标志位，所以不可能粘滞。
- **翻页（carousel）那一帧的滚动稳定化**：官方换内容时会 `.focus()` 一行且**不带 preventScroll**，
  浏览器会把 `.scrollable` 滚到那一行；再加上我们把「推理等级」那一行加高 ~48px 触发的
  scroll anchoring，翻页就会多出一次位移（看起来就是"动画被吃掉/交界处闪一下"）。
  现在：CSS 关掉 `overflow-anchor`（菜单根 + 官方的 `.scrollable`），JS 在 mutation 回调里
  **同步**把滚动位置清回 0（微任务，早于绘制），并新增 `focusNoScroll()` 统一入口
  （`focus({ preventScroll: true })`）供插件自己的聚焦使用。
- **慢档缓动对齐参考实现**：`.34s ease-in-out` → `.34s cubic-bezier(.45,.05,.35,1)`。
  快慢两档的判据、四层共用的 `--ces-slide` 机制、`prefers-reduced-motion` 的压制都没动。
- **目录索引构建包 try/catch**：某一行模型的数据坏了只影响那一行的徽标，不影响滑条与其它行。

### 测试

- 从 **337 项增加到 465 项**，新增第 19–26 节：
  字典与归一化 / `tiers()` 脏数据降级 / 三级检测（含快照与前缀）/ 目录优先（含"目录只给 id 时用字典补名"）；
  徽标（4/7/5/不变式 + 重扫不叠加 + 官方换节点后重算）；归属标签（位置 + 官方节点顺序 + 不叠加）；
  API 取值（文案 + title + 样式令牌）；滚动稳定化（类 + 滚动清零 + 后续每帧都清）；
  `focusNoScroll` 的行为与 `preventScroll`；禁用态投影（脏数据只禁一个模型、空快照不抛错）；
  8 档能量阶梯（`Max` = 11/14、`Ultra` = 1、全程单调）与端到端拖动。
- 第 26 节补上**预览页自洽性**：内联脚本引用的 id 必须都在、脚本要能真的跑起来
  （含 `?level=ultra` 路径）。这一条来自一次真实教训 —— 生成器是绿的、页面却白屏。
- 测试台补上：`classList` / `insertBefore` / `scrollTop` / `focus(options)` 记录、
  选择器的 **class 与子串匹配**（`.scrollable`、`[class*="optionCopy"]`）、
  以及假官方菜单的**两个二级页**（模型列表 + 档位列表）与多 provider 快照。

### 预览页

`node preview/make-preview.mjs` 生成的面板现在也画出这三处注记（直接复用从产物抽出来的真 CSS），
并新增 **8 档**按钮（Ultra 满星云、Max 已是中后段 11/14）。

---

## 1.1.0

### 观感：对齐 GPT 客户端的滑条

- **球比轨道大**：轨道 28 → 20px，球保持 28px，上下各浮出轨道 4px；球心在两端也压过轨道端头。
  （上游是"球直径恒等于轨道高"，两端会和轨道端头糊成一体，看着不像一颗球。）
- **球是真的圆**：DSH 主题给 `*` 设了 `corner-shape:superellipse(1.5)`，于是 `border-radius:50%`
  会被渲染成"圆角矩形"。现在 6 条带圆角的规则都显式写 `corner-shape:round`
  （DSH 自己的 Switch 也是这么做的）。
- 球的描边改淡（对齐客户端实测的 ~6% 压暗软光晕）。
- **Max 档不再显示其他档位的定位点**（那一档轨道已是紫色星云，灰点只剩噪点）。
- 修掉 off 档左侧漏出的蓝色月牙（填充层左端圆角与轨道端头不同心所致）。

### 手感：一档一格，不再跟手

- 拖动时旋钮**不跟随指针**，只停在档位点上；指针越过"每档 +1/3 档距"的判定线才换档。
- 按下（点空白处）= 点哪去哪（取最近档），到位过程是滑动。
- **快慢两档动画**：拖得慢用 `.34s ease-in-out`，拖得快用 `.16s cubic-bezier(.2,.9,.3,1)`；
  判据是两次换档的间隔（进入 320ms / 退出 200ms，带迟滞）。
- 跨多档时一段滑到位，不逐档连滑。

### 性能与交互

- 写回宿主从 120ms **节流**改成**停顿去抖**（260ms）：连续拖动期间 0 次写回，
  停手或松手才落地。上游的节流在连续拖动下约每秒打宿主 8 次，每次都要改会话推理档位
  （落盘 + 重渲染），实测会明显发卡。
- 指针移动但没换档时，不再去读会话状态。
- **去掉键盘操作**：滑条不接管方向键、不进 tab 序，官方菜单的键盘导航恢复原样
  （`role` / `aria-*` 保留，读屏仍能念出当前档位）。

### 工程

- **包名改为 `better-dsh-codex-effort-slider`**（与上游区分，两者可并存）：`cordis.patch.yml` 的插入 id 同步改成 `better-codex-effort-slider`，宿主与客户端里的 `PACKAGE_ID` / 模块 id 一起跟进。

- 补上 `pack-dist.ps1`（`package.json` 的 `npm run pack` 原本就引用它，但发布包里没有这个文件），
  产物为 `dist/better-dsh-codex-effort-slider-<version>.zip`，结构与上游一致：**zip 里是一层同名目录**。
- 清掉两处死代码：`.ces-track:focus-visible`（去掉键盘后不再可聚焦）与未被使用的 `indexFromPct`
  （按下取最近档现在直接用 `Math.round`）。
- 测试从 **265 项增加到 337 项**，新增段落覆盖：
  - off 档不漏色：按圆角矩形做 0.25px 步长采样，并反向验证"旧写法确实会漏"；
  - Max 档隐藏定位点：非 Max 不隐藏、拖到最右进入、拖回中间必须退出；
  - `corner-shape:round` opt-out：逐条钉住 6 个圆角规则；
  - 1/3 判定线、按下取最近档、按下后的第一档死区；
  - 起拖零额外延迟；连续拖动 0 次写回；快慢两档与迟滞。

### 已知未跟进的地方

- `preview/` 下的 4 张 README 配图仍是上游版本拍的**旧观感**（球=轨道高的那版），
  文字说明准确、图会显得旧。可用 `node preview/make-preview.mjs` 生成新的预览页后自行重拍。
- 上游 README 里"下载打包好的 zip"那条链接指向**上游仓库**的 release；发布到本仓库时请改成自己的地址。
