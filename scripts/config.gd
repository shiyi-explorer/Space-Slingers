class_name SSConfig
extends RefCounted

## 全局调参常量：物理手感、颜色、比分。所有数值集中在此便于调优。

const COLOR_SPACE := Color("071225")
const COLOR_STAR := Color("dcecff")
const COLOR_TRAIL := Color(0.55, 0.85, 1.0, 0.85)
const COLOR_PREVIEW := Color("ffd166")
const COLOR_SCORE := Color("f3c55e")
const COLOR_UI_GREEN := Color("43a047")
const COLOR_UI_GREEN_DARK := Color("2e7d32")

const LAUNCH_POWER := 8.5        ## 拉弓力度系数：发射速度 = 拉距 × 此值（满拉 ≈ 978，可读弹道）
const MAX_PULL := 115.0          ## 弹弓最大拉距（像素）
const MAX_LAUNCH_SPEED := 1000.0 ## 发射速度上限
const MAX_FLIGHT_SPEED := 1100.0 ## 飞行中速度上限（防止引力加速穿透）
const AIM_GRAB_RADIUS := 95.0    ## 抓取小鸟判定半径
const AIM_CANCEL_PULL := 22.0    ## 拉距低于此值松手 = 取消发射（不耗鸟）
const AIM_ELEVATION_MIN := 0.0     ## 发射仰角下限（度）
const AIM_ELEVATION_MAX := 60.0    ## 发射仰角上限（度）：高仰角可飞越行星顶
const AIM_ELEVATION_STEP := 2.0    ## 3D 拉弓中滚轮每格调整的仰角（度）
const BIRD_RADIUS := 16.0
const PREVIEW_STEPS := 600       ## 弹道预览模拟步数（dt = 1/120 = 5 秒）：覆盖高抛慢弧线全程
const PHYSICS_DT := 1.0 / 120.0

const BIRD_SETTLE_SPEED := 28.0  ## 低于此速度视为停稳
const BIRD_SETTLE_FRAMES := 50   ## 连续停稳帧数
const BIRD_MAX_LIFE := 9.0       ## 小鸟硬性存在时间（防永久绕轨）

const PIG_TOUCH_KILL := 60.0   ## 碰到就死：仅过滤静止接触（约 60 动量以下视为放置）
const COLOR_BIRD_KINDS := {
	"normal": Color("d9403f"),
	"split": Color("3f8fd9"),
	"dash": Color("f3b23a"),
}
const PIG_SCORE := 5000
const BLOCK_BONUS_PER_BIRD := 10000
