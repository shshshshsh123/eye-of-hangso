extends Resource
class_name ArtifactData

enum EMaterial { GOLD, SILVER, IRON, WOOD, STONE, LEATHER, GLASS, BONE }
enum ESignature { ROYAL, ARTISAN, FAKE_MARK, NONE, CURSE }
enum EType { WEAPON, ARMOR, POTION, TOOL, ACCESSORY, MISC }
enum EColor { RED, BLUE, GREEN, PURPLE, GOLD, SILVER, BLACK }
enum ERarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum EOrigin { ROYAL_CAPITAL, DWARF_MINE, ELF_FOREST, UNKNOWN }
enum ECondition { ACTIVE, DEPLETED, CORRUPTED }
enum ESpecialRule {
	NONE,           # 특이사항 없음
	MUST_BE_ACTIVE, # 마력 상태 반드시 ACTIVE
	MUST_BE_ARTISAN,# 각인 반드시 ARTISAN
	MUST_BE_ROYAL,  # 각인 반드시 ROYAL
	MUST_HAVE_CURSE # 각인 반드시 CURSE
}

@export var Id: String
@export var ArtifactName: String
@export var CorrectMaterial: EMaterial
@export var CorrectSignature: ESignature
@export var CorrectType: EType
@export var CorrectColor: EColor
@export var CorrectRarity: ERarity
@export var CorrectOrigin: EOrigin
@export var CorrectCondition: ECondition
@export var SpecialRule: ESpecialRule
@export var ArtifactImage: Texture2D
