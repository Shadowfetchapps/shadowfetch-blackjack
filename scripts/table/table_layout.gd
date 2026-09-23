class_name TableLayout
extends RefCounted
## World-space layout of the table (metres, Y up). The player sits on +Z looking
## toward the dealer on -Z. The felt is a half disc whose straight edge is the
## dealer side.

const FELT_Y := 0.760
const CENTER := Vector3(0.0, FELT_Y, -0.46)
const FELT_RADIUS := 1.06
const RAIL_RADIUS := 1.135

const CARD_W := 0.090
const CARD_H := 0.126
const CARD_T := 0.0011
const CARD_CORNER := 0.0058
const CHIP_RADIUS := 0.0215
const CHIP_HEIGHT := 0.0042

const SPOTS := {
	"main": {"pos": Vector2(0.0, 0.305), "radius": 0.062},
	"pp": {"pos": Vector2(-0.165, 0.330), "radius": 0.043},
	"t3": {"pos": Vector2(0.165, 0.330), "radius": 0.043},
}
const INSURANCE_POS := Vector2(-0.11, 0.02)
const SHOE_POS := Vector3(0.64, FELT_Y, -0.30)
const DISCARD_POS := Vector3(-0.64, FELT_Y, -0.30)
const RACK_POS := Vector3(0.0, FELT_Y, -0.395)
## Where the player's chips come from and go to (hidden just behind the rail).
const BANKROLL_POS := Vector3(0.0, FELT_Y + 0.03, 0.66)

## Seat angles (degrees from +X around the dealer) for the decorative empty seats.
const OTHER_SEATS: Array[float] = [22.0, 50.0, 130.0, 158.0]


static func spot_world(spot: String) -> Vector3:
	var p: Vector2 = SPOTS[spot]["pos"]
	return Vector3(p.x, FELT_Y, p.y)


## X centre of player hand `index` when there are `count` hands.
static func hand_x(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	var spacing := 0.235 if count == 2 else 0.205
	return (float(index) - (float(count) - 1.0) * 0.5) * spacing


## Position of card `card_index` in player hand `index` of `count`.
static func player_card(index: int, count: int, card_index: int) -> Vector3:
	var x := hand_x(index, count) - 0.018 + float(card_index) * 0.027
	var z := 0.165 - float(card_index) * 0.031
	return Vector3(x, FELT_Y + 0.0008 + float(card_index) * 0.0012, z)


static func player_bet(index: int, count: int) -> Vector3:
	if count <= 1:
		return spot_world("main")
	return Vector3(hand_x(index, count), FELT_Y, 0.262)


## Anchor just below a player hand (where its badge is drawn).
static func player_badge(index: int, count: int) -> Vector3:
	return Vector3(hand_x(index, count) + 0.01, FELT_Y + 0.02, 0.228)


static func dealer_card(card_index: int, count: int) -> Vector3:
	var spacing := 0.068
	var shift := maxf(0.0, float(count) - 2.0) * spacing * 0.5
	var x := -spacing * 0.5 + float(card_index) * spacing - shift
	return Vector3(x, FELT_Y + 0.0008 + float(card_index) * 0.0012, -0.262)


## Beside the dealer's last card.
static func dealer_badge(count: int = 2) -> Vector3:
	var last := dealer_card(maxi(count, 2) - 1, maxi(count, 2))
	return Vector3(last.x + CARD_W * 0.5 + 0.075, FELT_Y + 0.02, last.z - 0.02)


static func shoe_mouth() -> Vector3:
	return SHOE_POS + Vector3(-0.09, 0.05, 0.07)



## Felt UV for a world XZ point: u across X, v from the straight edge to the apex.
static func felt_uv(world_x: float, world_z: float) -> Vector2:
	return Vector2((world_x + FELT_RADIUS) / (2.0 * FELT_RADIUS), (world_z - CENTER.z) / FELT_RADIUS)
