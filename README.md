# Space Slingers · 太空版愤怒的小鸟

参照《愤怒的小鸟太空版》（Angry Birds Space）：弹弓发射小鸟，借行星引力圈
绕轨飞行，砸塌建筑消灭太空猪。

**提供两种游戏模式**，启动后先进入模式选择界面：

| 模式 | 场景 | 脚本 | 视角 | 特点 |
|---|---|---|---|---|
| **2D 经典** | `Main.tscn` | `scripts/` | 俯视平面 | 弹道清晰好读、角色贴图、星面可破坏障碍 |
| **3D 立体** | `Main3D.tscn` | `scripts3d/` | 俯视斜角（可旋转缩放） | 猪按球面纬度布置、星面障碍 2D/3D 同源、拉弓调仰角飞越行星击背面 |

两模式**共用** `data/levels.json` 关卡数据、`scripts/levels/` 解析器、后端 API 客户端和 UI 组件，
只是渲染维度与操作不同。关掉后端都能离线游玩（成绩存本地）。

---

## 核心机制（两模式共用）

- **太空引力**：引力圈内为向心加速度，按软化平方根反比衰减
  （表面最强 ≈ strength，2R 处约 20%，圈边平滑归零，圈外零重力）——
  靠近行星弯得更明显，圈外笔直，边界清晰可预测；弹弓落在小行星引力圈外，发射时没有"下坠偏置"
- **真刚体结构**：木/石/玻璃方块会倒塌、翻滚、压死猪；伤害 = 相对动量（折合质量 × 相对速度），轻碰不掉血
- **结构始终受力**：方块/猪全程吃向心引力，静置时被压在行星表面坐实（不浮空）；
  平方反比衰减让飞散的方块升高后受力骤减，塌方不会被"磁铁吸回"
- **特殊鸟**：蓝色分裂鸟（飞行中点击一分为三）、黄色加速鸟（飞行中点击冲刺）
- **掩体结构**：猪由立柱 + 横梁屋顶护住，可直射拆屋、打支撑让塔塌压杀，或绕到无遮蔽面偷袭
- **弹道预览**：拖拽时显示发光渐细带 + 落点准星 + 方向箭头，与运行时使用同一套加速度函数，所见即所得
- **飞行轨迹**：飞行中留下渐隐光带尾迹

### 2D 模式特有
- AI 生成的 3D 渲染角色贴图（红/蓝/黄鸟、普通猪、头盔猪），带呼吸/眨眼/死亡碎片动画
- 星面障碍：木、玻璃和石块依照关卡数据放置，落点与撞击方向影响能否命中目标

### 3D 模式特有
- 真三维布置：猪按经度角 + 纬度 lat 贴在球面任意位置（如第 2 关高纬度头盔猪）；两模式共用障碍的行星、角度和尺寸
- 拉弓滚轮调仰角，可飞越行星顶击背面；空白处拖拽/右键拖拽旋转视角，Q/E 旋转
- 地面投影线 + 冲击波 + 镜头震动；默认俯角 0.45 rad、缩放 0.58（下限 0.35）

---

## 操作

### 2D 模式
- 按住小鸟向后拖拽 → 松手发射；飞行中点击 = 触发特殊鸟技能
- 空白处拖拽平移视角、滚轮缩放、P 暂停、R 重开；左上圆钮：暂停 / 重开 / 选关
- 飞行中小鸟停稳或超时后自动消散，进入下一发

### 3D 模式
- 按住小鸟向后拖拽 → 松手发射；拉弓中滚轮调仰角（可飞越行星顶击背面）
- 飞行中点击 = 触发特殊鸟技能；空白处拖拽/右键拖拽 = 旋转视角；Q/E 旋转
- 未拉弓时滚轮或右上 +/− 缩放；P 暂停，R 重开

两模式通用：剩余小鸟每只结算奖励 10000 分；最高分按关卡存档（`user://space_slingers.cfg`）。成功通关至少一星；达到本关最省弹药目标（默认两发内通关）直接三星，也可按分数门槛获得二星或三星。选关会保留最佳评级和最少发射次数。

---

## 关卡

布局按 `data/levels.json` 的 `_design_notes` 约定设计。关卡数据只有一份：
Godot 离线用 `SSLevels` 读它，Scala 后端启动种子也读它，两侧统一经
`SSLevelCodec` 解析；后端下发失败自动回退本地数据（可玩，成绩标注未提交）。

| 关 | 名称 | 机制 |
|---|---|---|
| 1 | 第一轨道 | 同一颗星有近侧和上缘两个目标，先学直射，再用引力调整入射方向 |
| 2 | 背面打击 | 主星本体挡住背面目标，沿外缘绕行；木屋护着的近侧目标需结实直射 |
| 3 | 双星夹缝 | 两颗目标星错位排列，从间隙飞进远星；分裂鸟在夹缝中点开一箭双雕 |
| 4 | 卫星弹射 | 小卫星也有引力：先打它面向你的那头，再让弹道绕过大星下缘甩上背面 |
| 5 | 石堡攻坚 | 找玻璃支柱的弱点打塌石堡，或用加速鸟强拆；木塔上压着石板，打掉支撑让塔塌压杀 |
| 6 | 极地风暴 | 终章综合考：玻璃屋送分、卫星顶上有猪、极冠头盔猪、背面木屋，绕射/弹射/分裂齐射全用上 |

关卡里方位角 0° = 行星朝 +X 的背面、±180° = 朝弹弓的近侧、-90° = 行星顶部；掩体由
两根立柱（radial）+ 横梁屋顶（tangent）组成，屋顶 lift 需给柱顶外角留 ~2.5px 余量，
否则 3D 求解器会把屋顶侧踢下柱顶。材质是难度旋钮：玻璃一击即碎、木需实射、石要加速鸟或找弱点。
改关卡后重跑两模式的弹道可达性测试和结构静置测试。测试会检查行星遮挡、命中动量与掩体开局不塌。

---

## 结构

```text
ModeSelect.tscn / scripts/ui/mode_select.gd   ← 启动入口：2D/3D 模式选择
Main.tscn / scripts/                    ← 2D 经典模式
  main.gd             编排：引力施加、发射输入、镜头、比分、胜负
  config.gd           全局调参（力度/阈值/分值集中在此）
  physics/            gravity（平方根反比引力）/ impact（伤害度量）/ placement（贴球面放置）
  entities/           planet / bird / pig / block / slingshot（AI 贴图 + 动画）
  fx/starfield.gd     深空背景层
Main3D.tscn / scripts3d/                ← 3D 立体模式
  main3d.gd           编排：引力施加、发射输入、相机、比分、胜负、在线解析
  physics/            gravity3d / impact3d / placement3d（球面放置）
  entities3d/         planet3d / bird3d / block3d / pig3d / slingshot3d
  fx/                 debris_burst / shockwave / aim_preview
scripts/levels/                         ← 两模式共用
  level_data / level_codec（唯一解析器）/ levels（注册表）
data/levels.json                        ← 关卡唯一数据源（离线 Godot 与在线 Scala 都读）
scripts/ui/                             ← 两模式共用 UI
  hud / popup / fx_overlay / login_screen / level_select / mode_select
scripts/apis/                           ← 前后端 API 客户端（按服务分文件夹）
backend/                                Scala 3 后端（启动时读 data/levels.json 写 PG）
tests/
  logic_check.gd              2D 逻辑自检
  logic_check3d.gd            3D 逻辑自检
  reachability_check_2d.gd    2D 可通关性自检
  reachability_check.gd       3D 可通关性自检（枚举发射参数）
  structure_check.gd          2D 掩体静置自检（不塌、猪不误死）
  gravity_active_check.gd     3D 静置受力自检（逐关）
  level_source_check.gd       关卡单一数据源自检
```

---

## 运行与验证

```bash
GODOT=~/Downloads/Godot.app/Contents/MacOS/Godot

$GODOT --path .                                    # 启动 → 模式选择界面

# 2D 测试
$GODOT --headless --path . -s tests/logic_check.gd
$GODOT --headless --path . -s tests/reachability_check_2d.gd
$GODOT --headless --path . -s tests/structure_check.gd
# 3D 测试
$GODOT --headless --path . -s tests/logic_check3d.gd
$GODOT --headless --path . -s tests/reachability_check.gd
$GODOT --headless --path . -s tests/gravity_active_check.gd
# 共用
$GODOT --headless --path . -s tests/level_source_check.gd
```

### 可通关性
可达性测试用与运行时同源的引力积分（dt=1/120）枚举「方位 × 仰角 × 力度」，
验证每只猪都存在几何可达且动量足够的直击弹道，并检查鸟数 ≥ 猪数。
当前六关在两种模式下全部通过（3D 每轮枚举约 31 万条弹道）。改引力/关卡布局后务必重跑对应测试。

---

## 后端（可选，7 微服务，2026-11-26 落地）

后端 `backend/`：Scala 3.4.2 + Cats Effect + http4s + PostgreSQL（库 `space_slingers`，端口 8091）。
骨架平移自 dimension-zero（system/users 原样），按领域拆 7 服务 6 表：

| 服务 | 领域 | API |
|---|---|---|
| system | 共享基础设施（路由器/DB 会话/启动） | — |
| users | 登录、令牌、会话 | `login` / `getcurrentuser` |
| levels | 关卡配置下发（几何存 JSONB，服务端预存理论满分） | `getleveldefinition` |
| progress | 解锁进度（通过 N 开 N+1） | `loadprogress` / `saveprogress` |
| records | 成绩写入 + 合理性校验 | `submitlevelresult` |
| leaderboard | 排行榜读模型 | `getleaderboard` / `getplayerrank` |
| stats | 统计聚合（增量表） | `getplayerstats` |

**不开后端也能玩**：启动后在模式选择进任一模式，点「离线游玩」即可，
六关全开（选关页滚轮可翻到下面三关），最高分存本地，选关星级按最高分计算。
后端只用来登录、提交成绩、排行榜和解锁进度。

前端 `scripts/apis/`：按服务分文件夹、每 API 一个字段+send() 的类，
令牌/发送/命名推导集中在 transport.gd + api_name.gd。
物理模拟必须留在 Godot（60fps 本地积分，网络化不可行）；服务端无法复验弹道，反作弊只做合理性边界。
后端可用环境变量 `SS_LEVELS_JSON` 指定关卡 JSON 路径。

启动后端：
```bash
createdb space_slingers          # 首次
cd backend && sbt run            # 端口 8091
```
