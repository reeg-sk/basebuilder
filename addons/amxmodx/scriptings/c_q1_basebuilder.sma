/*
c_q1_basebuilder.sma

Release 2018 V1.2 (ZAKLADNA)

Pohyb z blokmi +use (E)
Hook pocas stavby +reload (R)

==========================
	<{ CREDITS }>
		Tirant, 
	xPaw, 
		HamletEagle, 
	Exolent, 
		-Acid-, 
	ILUSYION, 
		One Above All, 
	Emerald, 
		DarkGL, 
	Krot@L

	[ THANK YOU! ]
===========================

Navrhy co pridat/odstranit:
+?pridat config
+?pridat multilang
+?pridat specialne zbrane (po padnuti kluca)

-?rekurzia (xd)
__________________________
*/
#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <cstrike>
#include <fun>
#include <xs>
#include <dhudmessage>
#include <sqlx>

/**
PREMIUM JE NASTAVENE NA ADMIN_LEVEL_H
ADMIN JE NASTAVENY NA ADMIN_BAN
**/

/* DEFINICIE - UPRAVIT PODLA POTREBY */
// nezabudni zmenit!
#define HOST				"database host"
#define USER				"database username "
#define PASS				"database password"
#define DTBZ				"database name"

#define START_POINTS		100

#define PREFIX				"[BaseBuilder]" // Prefix pred spravami z ColorChatu

#define VERSION				"1.2" // Verzia
#define MAXENTS				512

#define BUILDTIME 			90 // Cas na stavanie
#define HIDETIME			30 // Cas na schovanie

#define BLOCK_RESERVE_PREMIUM		8 // Rezervacia blokov pre PREMIUM hraca
#define BLOCK_RESERVE_NORMAL		6 // Rezervacia blokov pre NOPREMIUM hraca

/* DEFINICIE BB */
#define IsZombie(%1)	    		( cs_get_user_team(%1) == CS_TEAM_T )
#define IsUserPremium(%1)		( get_user_flags( %1 ) & ADMIN_LEVEL_H )
#define IsUserAdmin(%1)	    		( get_user_flags( %1 ) & ADMIN_BAN )

#define IsConnected(%1)			( is_user_connected(%1) )
#define IsAlive(%1)			( is_user_alive(%1) )

#define MovingEnt(%1)     		( entity_set_int( %1, EV_INT_iuser2,     1 ) )
#define UnmovingEnt(%1)   		( entity_set_int( %1, EV_INT_iuser2,     0 ) )
#define IsMovingEnt(%1)   		( entity_get_int( %1, EV_INT_iuser2 ) == 1 )

#define SetEntMover(%1,%2)  		( entity_set_int( %1, EV_INT_iuser3, %2 ) )
#define UnsetEntMover(%1)   		( entity_set_int( %1, EV_INT_iuser3, 0  ) )
#define GetEntMover(%1)   		( entity_get_int( %1, EV_INT_iuser3     ) )

#define SetLastMover(%1,%2) 		( entity_set_int( %1, EV_INT_iuser4, %2 ) )
#define UnsetLastMover(%1)  		( entity_set_int( %1, EV_INT_iuser4, 0  ) )
#define GetLastMover(%1)  		( entity_get_int( %1, EV_INT_iuser4     ) )

/* ZAKLADNE PREMENNE */
new g_iMaxPlayers, g_iEntBarrier, g_iSayText;

new Float:g_fEntDist[33], Float:g_fOffset[33][3];
new g_EntOwner[MAXENTS], g_LastMover[MAXENTS];

new g_iOwnedEnt[33], g_iOwnedEntities[33];

new p_Body[33], p_XP[33];

new p_Vylepsenia[5][33], p_ZMVylepsenia[6][33], p_AllVylepsenia[3][33];
new p_MaxHP[33], g_friend[33];

new bool:g_boolPrepTime, bool:g_CanBuild, bool:all_GodMode, bool:g_KoniecKola, count_down;
new CsTeams:g_pTeam[33], CsTeams:g_pCurTeam[33];

new g_HudChannel_count, g_HudChannel_info, gHudSyncInfo, HudSync;

new Handle:g_SqlTuple;
new g_Error[512];

/* TASKY */
enum (+= 5000)
{
	TASK_BUILD,
	TASK_PREPTIME,

	TASK_RESPAWN,
	TASK_INFO,

	TASK_REGEN,
	TASK_MUTACIA,
	
	TASK_NORELOAD,

	TASK_ROUNDBODY,
	TASK_ROUNDCHANCE
}

/*** HOOK ***/
new bool:g_bHook[33];

new gHookOrigins[33][3];
new g_iHook;

/*** PREMENNE K VYLEPSENIAM ***/
new Float: cl_pushangle[33][3];
const NOCLIP_WPN_BS	= ((1<<2)|(1<<CSW_HEGRENADE)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_KNIFE)|(1<<CSW_C4))
const SHOTGUNS_BS    = ((1<<CSW_M3)|(1<<CSW_XM1014))

const m_pPlayer            		= 41;
const m_iId                		= 43;
const m_flNextPrimaryAttack    		= 46;
const m_flNextSecondaryAttack   	= 47;
const m_flTimeWeaponIdle		= 48;
const m_fInReload            		= 54;
const m_flNextAttack 			= 83;

static gmsgBarTime2;
static Ham:Ham_Player_ResetMaxSpeed = Ham_Item_PreFrame;

/* VYLEPSENIA */
enum _:UpgradeItems
{
	UpgradeName[64], UpgradeDesc[12], UpgradeMax[32], UpgradeCost[32]
}
enum _:UpgradeItemsBoth
{
	UpgradeName[64], UpgradeDesc[12], UpgradeMax[32], UpgradeCost[32], bool:UpgradePay
}
static const UpgradyCT[][UpgradeItems] = {
	// Nazov upgradu, maximálny level, cena
	{"Zvysene poskodenie", "+1%", 50, 260},
	{"Mensi recoil", "-1%", 50, 260},
	{"Rychlejsie prebijanie", "+1%", 50, 250},
	{"Kriticky zasah", "+1%", 50, 260}
}
static const UpgradyZM[][UpgradeItems] = {
	// Nazov upgradu, maximálny level, cena
	{"Zivot", "+40HP", 200, 260},
	{"Brnenie", "+5AP", 50, 240},
	{"Gravitacia", "-1%", 50, 220},
	{"Neviditelnost", "+1%", 45, 260},
	{"Rychlost", "+1%", 50, 250}
}
static const UpgradyAll[][UpgradeItemsBoth] = {
	// Nazov upgradu, maximálny level, cena, BODY = false / XP = true
	{"Zisk bodov", "+10 bodov", 10, 4500, true},
	{"Zisk XP", "+2 XP", 10, 10000, false}
}

/*** ZBRANE ***/
new g_iWeaponPicked[2][33], 
	bool:g_iWeaponsTaken[33],
	g_iWeaponsUnlocked[15][33],
	g_iSecondaryUnlocked[6][33];

enum _:WeaponsInfo
{
	WeaponName[32], WeaponsEnt[64], WeaponCost[32]
}

static const MenuWeapons[][WeaponsInfo] = {
	{}, // Nazov, item, cena 
	{"M4A1", "weapon_m4a1", 1200},
	{"AK47", "weapon_ak47", 1500},
	{"Famas", "weapon_famas", 700},
	{"Galil", "weapon_galil", 850},
	{"AWP", "weapon_awp", 900},
	{"Scout", "weapon_scout", 600},
	{"AUG", "weapon_aug", 550},
	{"SG550", "weapon_sg550", 550},
	{"MP5 Navy", "weapon_mp5navy", 520},
	{"UMP45", "weapon_ump45", 500},
	{"P90", "weapon_p90", 480},
	{"M3", "weapon_m3", 800}
	/*{"XM1014", "weapon_xm1014", 950},
	{"M249", "weapon_m249", 8000}*/
}

static const SecondaryWeapons[][WeaponsInfo] = {
	{}, // Nazov, item, cena
	{"Dual Elite", "weapon_elite", 650},
	{"Fiveseven", "weapon_fiveseven", 500},
	{"USP", "weapon_usp", 399},
	{"Glock", "weapon_glock18", 420},
	{"Deagle", "weapon_deagle", 620} 
}

/*** MARKET ***/
new bool:g_iMarketUpgrades[5][33];
new bool:g_iMarketItems[4][33];
new bool:g_iMarketBuffs[3][33];

enum _:MarketEnums
{
	MarketName[32], MarketDescription[64], MarketCost[32]
}

enum _:DifMarketEnums
{
	SpecialName[40], SpecialDesc[64], SpecialPrice[32], CsTeams:ForTeam[12]
}

static const MarketUpgrades[][MarketEnums] = {
	{"Damage", "zvysi damage o 10%", 500},
	{"Extra damage", "zvysi damage o 20%", 800},
	{"Recoil", "mensi recoil o 15%", 600},
	{"Prebijanie", "rychlost prebijania zvysena o 20%", 700},
	{"Regeneracia", "pridava 5% zivota kazde 2 sekundy", 550} 
}

static const MarketItems[][DifMarketEnums] = {
	{"Bojova helma \d(ZOMBIE)", "prida 100AP a Helmu", 200, CS_TEAM_T},
	{"Halucinacny granat \d(STAVITEL)", "oslepi vsetkych nepriatelov v okoli", 300, CS_TEAM_CT},
	{"Zapalny granat \d(STAVITEL)", "zapali vsetkych nepriatelov v okoli", 250, CS_TEAM_CT},
	{"Stit mutacie \d(ZOMBIE)", "neznicitelny stit, ktorym odrazis vsetky rany", 1400, CS_TEAM_T}
}

static const MarketBuffs[][DifMarketEnums] = {
	{"Mutacia \d(ZOMBIE)", "regeneruje 20% zivota kazde 2 sekundy", 850, CS_TEAM_T},
	{"Zbesilost \d(STAVITEL)", "bez prebijania po dobu 30 sekund", 750, CS_TEAM_CT}
}

// Zbesilost -- Credits: -Acid-
#define OFFSET_CLIPAMMO        51
#define OFFSET_LINUX_WEAPONS    4
#define fm_cs_set_weapon_ammo(%1,%2)    set_pdata_int(%1, OFFSET_CLIPAMMO, %2, OFFSET_LINUX_WEAPONS)

#define m_pActiveItem 373

new const g_MaxClipAmmo[] = 
{
    0,
    13, //CSW_P228
    0,
    10, //CSW_SCOUT
    0,  //CSW_HEGRENADE
    7,  //CSW_XM1014
    0,  //CSW_C4
    30,//CSW_MAC10
    30, //CSW_AUG
    0,  //CSW_SMOKEGRENADE
    15,//CSW_ELITE
    20,//CSW_FIVESEVEN
    25,//CSW_UMP45
    30, //CSW_SG550
    35, //CSW_GALIL
    25, //CSW_FAMAS
    12,//CSW_USP
    20,//CSW_GLOCK18
    10, //CSW_AWP
    30,//CSW_MP5NAVY
    100,//CSW_M249
    8,  //CSW_M3
    30, //CSW_M4A1
    30,//CSW_TMP
    20, //CSW_G3SG1
    0,  //CSW_FLASHBANG
    7,  //CSW_DEAGLE
    30, //CSW_SG552
    30, //CSW_AK47
    0,  //CSW_KNIFE
    50//CSW_P90
}

/*** LEVELY ***/
#define MaxLevels 12
new Level[33];

// Pocet XP, ktore potrebuje na level
static const Levels[MaxLevels] = 
{
	50,
	200,
	400, 
	600, 
	800, 
	1250,
	2000, 
	3000, 
	4005,
	5999,
	7125,
	8888 
}
// Nazvy rankov za level - zmen si to ked chces
static const LvlPrefix[MaxLevels +1][] =
{
	"New", 
	"Noob", 
	"Mouse", 
	"Freak",
	"Jumbo", 
	"Rambo",  
	"Butcher", 
	"Neo",
	"Assassin",
	"ThePro", 
	"Unstoppable", 
	"Darth",
	"Boomer"
}

/*** PADANIE ITEMOV ***/
new g_iDropItems[3][33];

/*** NASTAVENIA ***/
new bool:g_Settings3D[33];

/*** REVENGER ***/
new bool:p_Revenger[33];

static const chainsaw_viewmodel[] = "models/basebuilder_q1/v_chainsaw.mdl";
static const chainsaw_playermodel[] = "models/basebuilder_q1/p_chainsaw.mdl";

static const chainsaw_sounds[][] =
{
	"chainsaw/chainsaw_deploy.wav",        // Deploy Sound (knife_deploy1.wav)
	"chainsaw/chainsaw_hit1.wav",        // Hit 1 (knife_hit1.wav)
	"chainsaw/chainsaw_hit2.wav",        // Hit 2 (knife_hit2.wav)
	"chainsaw/chainsaw_hit1.wav",        // Hit 3 (knife_hit3.wav)
	"chainsaw/chainsaw_hit2.wav",        // Hit 4 (knife_hit4.wav)
	"chainsaw/chainsaw_hitwall.wav",    // Hit Wall (knife_hitwall1.wav)
	"chainsaw/chainsaw_miss.wav",        // Slash 1 (knife_slash1.wav)
	"chainsaw/chainsaw_miss.wav",        // Slash 2 (knife_slash2.wav)
	"chainsaw/chainsaw_stab.wav"        // Stab (knife_stab1.wav)
}

static const oldknife_sounds[][] =
{
	"weapons/knife_deploy1.wav",    // Deploy Sound
	"weapons/knife_hit1.wav",    // Hit 1
	"weapons/knife_hit2.wav",    // Hit 2
	"weapons/knife_hit3.wav",    // Hit 3
	"weapons/knife_hit4.wav",    // Hit 4
	"weapons/knife_hitwall1.wav",    // Hit Wall
	"weapons/knife_slash1.wav",    // Slash 1
	"weapons/knife_slash2.wav",    // Slash 2
	"weapons/knife_stab.wav"    // Stab
}

/*** SPECIALNE KOLA ***/
new bool:WasRound = false;
new bool:round_DoubleBody, bool:round_DoubleChance;
new odpocet_specialbody = 300, odpocet_specialchance = 300;

/*** FARBY BLOKOV ***/
// odstranit niektore farby, ktore su zbytocne (nepouzivaju sa)
static const Float:g_Color[24][3] =
{
	{200.0, 000.0, 000.0},
	{255.0, 083.0, 073.0},
	{255.0, 117.0, 056.0},
	{255.0, 174.0, 066.0},
	{255.0, 207.0, 171.0},
	{252.0, 232.0, 131.0},
	{254.0, 254.0, 034.0},
	{059.0, 176.0, 143.0},
	{197.0, 227.0, 132.0},
	{000.0, 150.0, 000.0},
	{120.0, 219.0, 226.0},
	{135.0, 206.0, 235.0},
	{128.0, 218.0, 235.0},
	{000.0, 000.0, 255.0},
	{146.0, 110.0, 174.0},
	{255.0, 105.0, 180.0},
	{246.0, 100.0, 175.0},
	{205.0, 074.0, 076.0},
	{250.0, 167.0, 108.0},
	{234.0, 126.0, 093.0},
	{180.0, 103.0, 077.0},
	{149.0, 145.0, 140.0},
	{000.0, 000.0, 000.0},
	{255.0, 255.0, 255.0}
}

static const Float:g_RenderColor[24] =
{
	100.0, //Red
	135.0, //Red Orange
	140.0, //Orange
	120.0, //Yellow Orange
	140.0, //Peach
	125.0, //Yellow
	100.0, //Lemon Yellow
	125.0, //Jungle Green
	135.0, //Yellow Green
	100.0, //Green
	125.0, //Aquamarine
	150.0, //Baby Blue
	090.0, //Sky Blue
	075.0, //Blue
	175.0, //Violet
	150.0, //Hot Pink
	175.0, //Magenta
	140.0, //Mahogany
	140.0, //Tan
	140.0, //Light Brown
	165.0, //Brown
	175.0, //Gray
	125.0, //Black
	125.0 //White
}

static const g_ColorName[24][] =
{
	"Cervena",
	"Cerveno oranzova",
	"Oranzova",
	"Zlto oranzova",
	"Broskynova",
	"Zlta",
	"Citronova",
	"Dzunglovo zelena",
	"Zlto zelena",
	"Zelena",
	"Svetlo modra",
	"Bielo modra",
	"Modra obloha",
	"Modra",
	"Fialova",
	"Ruzova",
	"Purpurova",
	"Mahagonova",
	"Zlto hneda",
	"Svetlo hneda",
	"Hneda",
	"Siva",
	"Cierna",
	"Biela"
}

new g_pColor[33] = 0;

/*** MODELY ***/
static g_ZombiePremium[] = "premium_t";
static g_HumanPremium[] = "premium_ct";

static ZombieModel[] = "classic_q1";

static ZombieHands[] = "models/basebuilder_q1/v_zombiehands2.mdl";

static ZombieShield_v[] = "models/basebuilder_q1/v_RiotShield.mdl";
static ZombieShield_w[] = "models/basebuilder_q1/w_RiotShield.mdl";
static ZombieShield_p[] = "models/basebuilder_q1/p_RiotShield.mdl";

/*** SOUNDY ***/
static g_UpgradeMenuBuy[] = "events/enemy_died.wav";
static g_MenuUnlock[] = "weapons/sshell1.wav";
static g_MarketBuy[] = "items/smallmedkit1.wav";
static g_ZombKill[] = "basebuilder_q1/zombie_kill.wav";
static g_DropItem[] = "basebuilder_q1/itemdrop.wav";

static const g_RoundStart[][] = {
	"basebuilder_q1/round_start.wav",
	"basebuilder_q1/round_start2.wav"
}

static const g_PhaseHide[][] = {
	"basebuilder_q1/phase_prep.wav",
	"basebuilder_q1/phase_prep3.wav"
}

static g_PhaseBuild[] = "basebuilder_q1/phase_build3.wav";

static const g_ZombieWin[][] = {
	"basebuilder_q1/win_zombies.wav",
	"basebuilder_q1/win_zombies2.wav"
}

static const g_BuilderWin[][] = {
	"basebuilder_q1/win_builders.wav",
	"basebuilder_q1/win_builders2.wav"
}

static g_BuildSong[][] = {
	"basebuilder_q1/build_1.mp3",
	"basebuilder_q1/build_2.mp3",
	"basebuilder_q1/build_3.mp3"
}

public plugin_init() {
	register_plugin("BaseBuilder", VERSION, "ReeG"); 
	// https://steamcommunity.com/id/reeg-ru

	/** ZACIATOK A KONIEC KOLA **/
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0");
	register_logevent("logevent_round_start", 2, "1=Round_Start") 
	register_logevent("logevent_round_end", 2, "1=Round_End");

	/** SPAWN & SMRT **/
	RegisterHam(Ham_Spawn, "player", "ham_PlayerSpawn_Post", 1);
	RegisterHam(Ham_Killed, "player", "ham_Player_Killed", 0);

	/** HLAVNE MENU **/
	register_clcmd("chooseteam", "clcmd_changeteam");
	register_clcmd("jointeam", "clcmd_changeteam");

	register_clcmd("say /menu", "MainMenu");
	register_clcmd("say_team /menu", "MainMenu");

	register_clcmd("say /respawn", "cmdRespawn");
	register_clcmd("say_team /respawn", "cmdRespawn");

	register_clcmd("say /guns", "GunsMenu");
	register_clcmd("say_team /guns", "GunsMenu");

	register_clcmd("say /unlock", "UnlockGuns");
	register_clcmd("say_team /unlock", "UnlockGuns");

	register_clcmd("say /market", "MarketMenu");
	register_clcmd("say_team /market", "MarketMenu");

	register_clcmd("say /items", "DropItemMenu");
	register_clcmd("say_team /items", "DropItemMenu");

	/** HOOK **/
	register_clcmd("+hook", "hook_on");
	register_clcmd("-hook", "hook_off");

	/* * POHYB Z BLOKMI * */
	register_forward(FM_CmdStart, "fw_CmdStart");
	register_forward(FM_TraceLine, "fw_Traceline", 1);

	/** ZABLOKOVANIE KILL V KONZOLE **/
	register_forward(FM_ClientKill, "fwdClientKill"); 

	/** ODSTRANI DEAD ZOMBIES **/
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);

	/** REVENGER **/
	register_forward(FM_EmitSound, "fw_EmitSound");

	/** LOOK INFO **/
	register_event("StatusValue", "ev_SetTeam", "be", "1=1");
	register_event("StatusValue", "ev_ShowStatus", "be", "1=2", "2!0");
	register_event("StatusValue", "ev_HideStatus", "be", "1=1", "2=0");

	/** UPGRADES **/
	register_clcmd("say /upgrade", "RozcestnikUpgrades");
	register_clcmd("say_team /upgrade", "RozcestnikUpgrades");

	RegisterHam(Ham_TakeDamage, "player", "hook_TakeDamage");
	RegisterHam(Ham_Player_ResetMaxSpeed ,"player" , "playerResetMaxSpeed" ,1);

	static weapon_name[32];
	for (new i = 1; i <= 30; i++) {
		if (!(NOCLIP_WPN_BS & 1 << i) && !(SHOTGUNS_BS & (1<<i)) && get_weaponname(i, weapon_name, 23)) {
			RegisterHam(Ham_Weapon_PrimaryAttack, weapon_name, "fw_Weapon_PrimaryAttack_Pre");
			RegisterHam(Ham_Weapon_PrimaryAttack, weapon_name, "fw_Weapon_PrimaryAttack_Post", 1);
			RegisterHam(Ham_Weapon_Reload, weapon_name, "Weapon_Reload", 1);
			RegisterHam(Ham_Item_Holster, weapon_name, "Item_Holster");
		}
	}

	gmsgBarTime2 = get_user_msgid("BarTime2");

	/** AUTO JOIN **/
	register_message(get_user_msgid("ShowMenu"), "message_show_menu");
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu");

	/** NEKONECNA MUNICIA **/
	register_event("AmmoX", "ev_AmmoX", "be", "1=1", "1=2", "1=3", "1=4", "1=5", "1=6", "1=7", "1=8", "1=9", "1=10");
	register_message(get_user_msgid("StatusIcon"), "msgStatusIcon");

	RegisterHam(Ham_Touch, "weapon_shield", "ham_WeaponCleaner_Post", 1);
	RegisterHam(Ham_Touch, "weaponbox", "ham_WeaponCleaner_Post", 1);

	/** ROUND END MSGS **/
	register_message(get_user_msgid("TextMsg"),	"msgSendAudio");
	register_message(get_user_msgid("TextMsg"), "msgRoundEnd");

	/** PREFIX + LEVELS **/
	g_iSayText = get_user_msgid("SayText");
	register_message(g_iSayText, "Message_SayText");

	register_clcmd("drop", "clcmd_dropitem");
	register_clcmd("buy", "clcmd_blocked");
	register_clcmd("radio1", "clcmd_blocked");
	register_clcmd("radio2", "clcmd_blocked");
	register_clcmd("radio3", "clcmd_blocked");

	register_clcmd("bb_colors", "clcmd_showcolors");

	/** MODELY **/
	register_event("CurWeapon" , "ev_CurWeapon" , "be" , "1=1");

	register_forward(FM_GetGameDescription, "fw_GetGameDescription");

	/* OSTATNE */
	g_HudChannel_info = CreateHudSyncObj();
	g_HudChannel_count = CreateHudSyncObj();
	gHudSyncInfo = CreateHudSyncObj();
	HudSync = CreateHudSyncObj();

	g_iMaxPlayers = get_maxplayers();
	g_iEntBarrier = find_ent_by_tname(-1, "barrier");

	register_clcmd("say", "CmdSay");
	register_clcmd("say_team", "CmdSay");

	set_task(1.0, "MySql_Init");
}

public plugin_precache() {
	new szModel[64], i;

	g_iHook = precache_model("sprites/basebuilder_q1/hook.spr");
	precache_model("models/rpgrocket.mdl");

	formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", g_ZombiePremium, g_ZombiePremium);
	precache_model(szModel);

	formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", g_HumanPremium, g_HumanPremium);
	precache_model(szModel);

	formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", ZombieModel, ZombieModel);
	precache_model(szModel);

	precache_model(ZombieHands);

	precache_model(ZombieShield_v);
	precache_model(ZombieShield_w);
	precache_model(ZombieShield_p);
	precache_sound(g_UpgradeMenuBuy);
	precache_sound(g_MenuUnlock);
	precache_sound(g_MarketBuy);
	precache_sound(g_ZombKill);
	precache_sound(g_DropItem);

	precache_sound(g_PhaseBuild);

	precache_model(chainsaw_viewmodel);
	precache_model(chainsaw_playermodel);

	for(i = 0; i < sizeof chainsaw_sounds; i++)
		precache_sound(chainsaw_sounds[i]);

	for(i = 0; i < sizeof g_BuildSong; i++)
		precache_sound(g_BuildSong[i]);

	for(i = 0; i < sizeof g_RoundStart; i++)
		precache_sound(g_RoundStart[i]);

	for(i = 0; i < sizeof g_PhaseHide; i++)
		precache_sound(g_PhaseHide[i]);

	for(i = 0; i < sizeof g_BuilderWin; i++)
		precache_sound(g_BuilderWin[i]);

	i = create_entity("info_bomb_target");
	entity_set_origin(i, Float:{8192.0,8192.0,8192.0})

	i = create_entity("info_map_parameters");
	DispatchKeyValue(i, "buying", "3");
	DispatchKeyValue(i, "bombradius", "1");
	DispatchSpawn(i);
}

/* MYSQL UKLADANIE */
public MySql_Init()
{
    g_SqlTuple = SQL_MakeDbTuple(HOST, USER, PASS, DTBZ);
   
    new ErrorCode,Handle:SqlConnection = SQL_Connect(g_SqlTuple,ErrorCode,g_Error,charsmax(g_Error));
    if(SqlConnection == Empty_Handle) {
	set_fail_state(g_Error);
    }
       
    new Handle:Queries;
    Queries = SQL_PrepareQuery(SqlConnection,"CREATE TABLE IF NOT EXISTS basebuilder_save (steamid VARCHAR(32),body INT(11), exp INT(11), farba INT(2), item_zatmenie INT(1), item_kluc INT(1), item_aurora INT(1), vylepsenia_zm VARCHAR(20), vylepsenia_hm VARCHAR(16), vylepsenia_all VARCHAR(6), zbrane_primary VARCHAR(32), zbrane_pistole VARCHAR(12), PRIMARY KEY (`steamid`))");
	
    if(!SQL_Execute(Queries))
    {
        SQL_QueryError(Queries,g_Error,charsmax(g_Error));
        set_fail_state(g_Error);
       
    }
    
    SQL_FreeHandle(Queries);
   
    SQL_FreeHandle(SqlConnection);  
}

public plugin_end()
{
    SQL_FreeHandle(g_SqlTuple);
}

public Load_MySql(id)
{
    new szSteamId[32], szTemp[512];
    get_user_authid(id, szSteamId, charsmax(szSteamId));
    
    new Data[1];
    Data[0] = id;

    format(szTemp,charsmax(szTemp),"SELECT * FROM `basebuilder_save` WHERE (`basebuilder_save`.`steamid` = '%s')", szSteamId);
    SQL_ThreadQuery(g_SqlTuple, "register_client", szTemp, Data, 1);
}

public register_client(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
    if(FailState == TQUERY_CONNECT_FAILED)
    {
        log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error);
    }
    else if(FailState == TQUERY_QUERY_FAILED)
    {
        log_amx("Load Query failed. [%d] %s", Errcode, Error);
    }

    new id;
    id = Data[0];
    
    if(SQL_NumResults(Query) < 1) 
    {
		new szSteamId[32];
		get_user_authid(id, szSteamId, charsmax(szSteamId));
        

		if (equal(szSteamId,"ID_PENDING"))
			return PLUGIN_HANDLED;
   
		new szTemp[512];
		format(szTemp,charsmax(szTemp),"INSERT INTO `basebuilder_save` (`steamid`, `body`, `exp`, `farba`, `item_zatmenie`, `item_kluc`, `item_aurora`, `vylepsenia_zm`, `vylepsenia_hm`, `vylepsenia_all`, `zbrane_primary`, `zbrane_pistole`) VALUES ('%s','%d', '0', '0', '0', '0', '0', '0#0#0#0#0', '0#0#0#0', '0#0', '0#0#0#0#0#1#0#0#0#0#0#0', '0#1#0#0#0');", szSteamId, START_POINTS);
		SQL_ThreadQuery(g_SqlTuple,"IgnoreHandle",szTemp);
    } else {
		p_Body[id] = SQL_ReadResult(Query, 1);
		p_XP[id] = SQL_ReadResult(Query, 2);

		CheckLevel(id);

		g_pColor[id] = SQL_ReadResult(Query, 3);

		g_iDropItems[0][id] = SQL_ReadResult(Query, 4);
		g_iDropItems[1][id] = SQL_ReadResult(Query, 5);
		g_iDropItems[2][id] = SQL_ReadResult(Query, 6);

		new szStringVylepseniaZM[25], szStringVylepseniaHM[25], szStringVylepseniaAll[25], szStringVylepseniaZbrane[44], szStringVylepseniaPistole[25];

		SQL_ReadResult(Query, 7, szStringVylepseniaZM, charsmax(szStringVylepseniaZM));
		SQL_ReadResult(Query, 8, szStringVylepseniaHM, charsmax(szStringVylepseniaHM));
		SQL_ReadResult(Query, 9, szStringVylepseniaAll, charsmax(szStringVylepseniaAll));

		SQL_ReadResult(Query, 10, szStringVylepseniaZbrane, charsmax(szStringVylepseniaZbrane));
		SQL_ReadResult(Query, 11, szStringVylepseniaPistole, charsmax(szStringVylepseniaPistole));

		replace_all(szStringVylepseniaZM, sizeof(szStringVylepseniaZM), "#", " ");
		new v_hp[11], v_ap[11], v_grav[11], v_inv[11], v_speed[11];
		parse(szStringVylepseniaZM, v_hp, 10, v_ap, 10, v_grav, 10, v_inv, 10, v_speed, 10);

		p_ZMVylepsenia[0][id] = str_to_num(v_hp);
		p_ZMVylepsenia[1][id] = str_to_num(v_ap);
		p_ZMVylepsenia[2][id] = str_to_num(v_grav);
		p_ZMVylepsenia[3][id] = str_to_num(v_inv);
		p_ZMVylepsenia[4][id] = str_to_num(v_speed);
		
		replace_all(szStringVylepseniaHM, sizeof(szStringVylepseniaHM), "#", " ");
		new v_dmg[11], v_rec[11], v_rel[11], v_crit[11];
		parse(szStringVylepseniaHM, v_dmg, 10, v_rec, 10, v_rel, 10, v_crit, 10);

		p_Vylepsenia[0][id] = str_to_num(v_dmg);
		p_Vylepsenia[1][id] = str_to_num(v_rec);
		p_Vylepsenia[2][id] = str_to_num(v_rel);
		p_Vylepsenia[3][id] = str_to_num(v_crit);

		replace_all(szStringVylepseniaAll, sizeof(szStringVylepseniaAll), "#", " ");
		new z_xp[11], z_body[11];
		parse(szStringVylepseniaAll, z_body, 10, z_xp, 10);

		p_AllVylepsenia[0][id] = str_to_num(z_body);
		p_AllVylepsenia[1][id] = str_to_num(z_xp);

		replace_all(szStringVylepseniaZbrane, sizeof(szStringVylepseniaZbrane), "#", " ");
		new gun_a[3], gun_b[3], gun_c[3], gun_d[3], gun_e[3], gun_f[3], gun_g[3], gun_h[3], gun_i[3], gun_j[3], gun_k[3], gun_l[3]; //, gun_m[3], gun_n[3];
		parse(szStringVylepseniaZbrane, gun_a, 2, gun_b, 2, gun_c, 2, gun_d, 2, gun_e, 2, gun_f, 2, gun_g, 2, gun_h, 2, gun_i, 2, gun_j, 2, gun_k, 2, gun_l, 2); //, gun_m, 2, gun_n, 2);

		g_iWeaponsUnlocked[1][id] = str_to_num(gun_a);
		g_iWeaponsUnlocked[2][id] = str_to_num(gun_b);
		g_iWeaponsUnlocked[3][id] = str_to_num(gun_c);
		g_iWeaponsUnlocked[4][id] = str_to_num(gun_d);
		g_iWeaponsUnlocked[5][id] = str_to_num(gun_e);
		g_iWeaponsUnlocked[6][id] = str_to_num(gun_f);
		g_iWeaponsUnlocked[7][id] = str_to_num(gun_g);
		g_iWeaponsUnlocked[8][id] = str_to_num(gun_h);
		g_iWeaponsUnlocked[9][id] = str_to_num(gun_i);
		g_iWeaponsUnlocked[10][id] = str_to_num(gun_j);
		g_iWeaponsUnlocked[11][id] = str_to_num(gun_k);
		g_iWeaponsUnlocked[12][id] = str_to_num(gun_l);
		//g_iWeaponsUnlocked[13][id] = str_to_num(gun_m);
		//g_iWeaponsUnlocked[14][id] = str_to_num(gun_n);

		replace_all(szStringVylepseniaPistole, sizeof(szStringVylepseniaPistole), "#", " ");
		new pistol_a[3], pistol_b[3], pistol_c[3], pistol_d[3], pistol_e[3];
		parse(szStringVylepseniaPistole, pistol_a, 2, pistol_b, 2, pistol_c, 2, pistol_d, 2, pistol_e, 2);

		g_iSecondaryUnlocked[1][id] = str_to_num(pistol_a);
		g_iSecondaryUnlocked[2][id] = str_to_num(pistol_b);
		g_iSecondaryUnlocked[3][id] = str_to_num(pistol_c);
		g_iSecondaryUnlocked[4][id] = str_to_num(pistol_d);
		g_iSecondaryUnlocked[5][id] = str_to_num(pistol_e);
    }
    
    return PLUGIN_HANDLED;
}

public Save_MySql(id)
{
    new szSteamId[32], szTemp[512];
    get_user_authid(id, szSteamId, charsmax(szSteamId));

    format(
		szTemp,charsmax(szTemp),
		"UPDATE `basebuilder_save` SET `body` = '%i', `exp` = '%i', `farba` = '%i', `item_zatmenie` = '%i', `item_kluc` = '%i', `item_aurora` = '%i', `vylepsenia_zm` = '%i#%i#%i#%i#%i', `vylepsenia_hm` = '%i#%i#%i#%i', `vylepsenia_all` = '%i#%i', `zbrane_primary` = '%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i', `zbrane_pistole` = '%i#%i#%i#%i#%i' WHERE `basebuilder_save`.`steamid` = '%s';"
		,p_Body[id], p_XP[id], g_pColor[id], g_iDropItems[0][id], g_iDropItems[1][id], g_iDropItems[2][id], p_ZMVylepsenia[0][id], p_ZMVylepsenia[1][id], p_ZMVylepsenia[2][id], p_ZMVylepsenia[3][id], p_ZMVylepsenia[4][id], p_Vylepsenia[0][id], p_Vylepsenia[1][id], p_Vylepsenia[2][id], p_Vylepsenia[3][id], p_AllVylepsenia[0][id], p_AllVylepsenia[1][id], 
		g_iWeaponsUnlocked[1][id], g_iWeaponsUnlocked[2][id], g_iWeaponsUnlocked[3][id], g_iWeaponsUnlocked[4][id], g_iWeaponsUnlocked[5][id], g_iWeaponsUnlocked[6][id], g_iWeaponsUnlocked[7][id], g_iWeaponsUnlocked[8][id], g_iWeaponsUnlocked[9][id], g_iWeaponsUnlocked[10][id], g_iWeaponsUnlocked[11][id], g_iWeaponsUnlocked[12][id]/*, g_iWeaponsUnlocked[13][id], g_iWeaponsUnlocked[14][id]*/,
		g_iSecondaryUnlocked[1][id], g_iSecondaryUnlocked[2][id], g_iSecondaryUnlocked[3][id], g_iSecondaryUnlocked[4][id], g_iSecondaryUnlocked[5][id],
		szSteamId
	);

    SQL_ThreadQuery(g_SqlTuple,"IgnoreHandle",szTemp);
}

public IgnoreHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
    SQL_FreeHandle(Query);
    return PLUGIN_HANDLED;
}

/* NAZOV MODU - GAME */
public fw_GetGameDescription()
{
	forward_return(FMV_STRING, "BaseBuilder Q1");
	return FMRES_SUPERCEDE;
}

/* PRIPOJENIE - ODPOJENIE - SPAWN - ZACIATOK KOLA - KONIEC KOLA - SMRT */
// Pripojenie
public client_putinserver(id) {
	p_MaxHP[id] = 100;
	g_iWeaponsUnlocked[7][id] = 1;
	g_iSecondaryUnlocked[3][id] = 1;

	g_iMarketItems[1][id] = false;
	g_iMarketItems[2][id] = false;
	g_iMarketItems[3][id] = false;

	if(task_exists(id + TASK_MUTACIA))  {
		remove_task(id + TASK_MUTACIA);
	}

	g_iMarketBuffs[0][id] = false;
	g_iMarketBuffs[1][id] = false;
	g_Settings3D[id] = false;

	p_Revenger[id] = false;

	if(task_exists(id + TASK_REGEN)) {
		remove_task(id + TASK_REGEN);
	}
	if(task_exists(id + TASK_MUTACIA)) {
		remove_task(id + TASK_MUTACIA);
	}
	if(task_exists(id + TASK_RESPAWN)) {
		remove_task(id + TASK_RESPAWN);
	}
	set_task(1.0, "ShowInfo", id+TASK_INFO, _, _, "b");

	if(!g_CanBuild || !g_boolPrepTime) {
		set_task(8.0, "Respawn_Zombie", id + TASK_RESPAWN);
	}
	Load_MySql(id);
}
// Odpojenie
public client_disconnect(id)
{
	if (IsMovingEnt(id)) {
		cmdStopEnt(id);
	}

	p_MaxHP[id] = 100;
	g_Settings3D[id] = false;

	p_Revenger[id] = false;

	g_iOwnedEntities[id] = 0;

	if(task_exists(id + TASK_RESPAWN)) {
		remove_task(id + TASK_RESPAWN);
	}
	if(task_exists(id + TASK_REGEN)) {
		remove_task(id + TASK_REGEN);
	}
	if(task_exists(id + TASK_MUTACIA)) {
		remove_task(id + TASK_MUTACIA);
	}
	Save_MySql(id);
}
// Spawn
public ham_PlayerSpawn_Post(id)
{	
	if (!IsAlive(id) || !IsConnected(id)) {
		return PLUGIN_HANDLED;
	}

	strip_user_weapons(id);
	give_item(id, "weapon_knife");
	g_pCurTeam[id] = cs_get_user_team(id);
	cs_reset_user_model(id);

	g_iMarketItems[1][id] = false;
	g_iMarketItems[2][id] = false;
	g_iMarketItems[3][id] = false;

	if(task_exists(id + TASK_MUTACIA))
		remove_task(id + TASK_MUTACIA);

	g_iMarketBuffs[0][id] = false;
	g_iMarketBuffs[1][id] = false;

	switch(cs_get_user_team(id)) {
		case CS_TEAM_T: {
			p_MaxHP[id] = 2000 + 40 * p_ZMVylepsenia[0][id] + 40 * Level[id];
			if(g_iDropItems[0][id] == 1) p_MaxHP[id] += 200;
			set_user_health(id, p_MaxHP[id]);
			if(p_ZMVylepsenia[1][id] > 0) give_item(id, "item_kevlar");
			if(g_iMarketItems[0][id]) give_item(id, "item_assaultsuit");
			set_user_armor(id, 5 * p_ZMVylepsenia[1][id]);
			new Float:set_zombie_grav = 1.0 - (0.013 * p_ZMVylepsenia[2][id]);
			set_user_gravity(id, set_zombie_grav);
			set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransTexture, 255 - 5 * p_ZMVylepsenia[3][id]);

			MainMenu(id);

			if(IsUserPremium(id)) {
				cs_set_user_model(id, g_ZombiePremium);
			} else {
				cs_set_user_model(id, ZombieModel);
			}
			
		}
		case CS_TEAM_CT: {
			p_MaxHP[id] = 100;
			if(g_iDropItems[0][id] == 1) p_MaxHP[id] += 25;
			p_MaxHP[id] += 5 * Level[id];
			set_user_health(id, p_MaxHP[id]);
			set_user_armor(id, 5 * p_ZMVylepsenia[1][id]);
			set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 255);
			set_user_gravity(id, 1.0);

			if(g_iDropItems[2][id] == 1) set_user_rendering(id, kRenderFxGlowShell, 255, 255, 0, kRenderNormal, 15);

			if(IsUserPremium(id)) cs_set_user_model(id, g_HumanPremium);
			if(g_boolPrepTime) GunsMenu(id);

			if(p_Revenger[id]) {
				give_item(id, "weapon_usp");
				set_user_rendering(id, kRenderFxGlowShell, 155, 10, 0, kRenderNormal, 15);
				set_user_health(id, 600);
				set_user_armor(id, 200);
				set_user_gravity(id, 0.60);
			}
		}
	}
	return PLUGIN_HANDLED;
}
// Zaciatok kola (pred freezetime)
public event_round_start()
{
	arrayset(g_iOwnedEntities, 0, 33);
	arrayset(g_EntOwner, 0, MAXENTS);
	arrayset(g_LastMover, 0, MAXENTS);

	g_CanBuild = true;
	g_boolPrepTime = false;
	all_GodMode = true;
	g_KoniecKola = false;

	if(!WasRound) {
		new spustis_kolo = random_num(0, 20);
		switch(spustis_kolo) {
			case 19: {
				new nahodne_kolo = random_num(0,1);

				switch(nahodne_kolo) {
					case 0: {
						round_DoubleBody = true;
						odpocet_specialbody = 300;
						set_task(1.0, "SpecialRoundBody", TASK_ROUNDBODY,_, _, "a", odpocet_specialbody);

						for(new i = 0; i < 4;i++)
							ChatColor(0, "!gZacina nahodny event !tDvojite body!g!");
					}
					case 1: {
						round_DoubleChance = true;
						odpocet_specialchance = 300;
						set_task(1.0, "SpecialRoundChance", TASK_ROUNDCHANCE,_, _, "a", odpocet_specialchance);

						for(new i = 0; i < 4;i++)
							ChatColor(0, "!gZacina nahodny event !tDvojita sanca!g!");
					}
				}
			}
		}
		WasRound = true;
	}

	remove_task(TASK_PREPTIME);

	new cname[10], tname[7];
	for(new iEnt = g_iMaxPlayers+1; iEnt < MAXENTS; iEnt++)
	{
		if(is_valid_ent(iEnt))
		{
			entity_get_string(iEnt, EV_SZ_classname, cname, 9);
			entity_get_string(iEnt, EV_SZ_targetname, tname, 6);
			if(iEnt != g_iEntBarrier && equal(cname, "func_wall") && !equal(tname, "ignore"))
			{
				engfunc(EngFunc_SetOrigin, iEnt, Float:{ 0.0, 0.0, 0.0 });
			}
		}
	}
}

// Specialne kola
public SpecialRoundBody() {
	odpocet_specialbody--;

	if (odpocet_specialbody>=1) {
		set_dhudmessage(0, 255, 0, -1.0, 0.01, 0, 1.0, 1.0, 0.1, 0.2);
		show_dhudmessage(0, "[ SPECIALNE KOLO - DVOJITE BODY ]^nSekund do konca: %i", odpocet_specialbody);
	} else {
		ChatColor(0, "!gSpecialne kolo sa skoncilo!");
		round_DoubleBody = false;

		remove_task(TASK_ROUNDBODY);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public SpecialRoundChance() {
	odpocet_specialchance--;

	if (odpocet_specialchance>=1) {
		set_dhudmessage(0, 255, 0, -1.0, 0.01, 0, 1.0, 1.0, 0.1, 0.2);
		show_dhudmessage(0, "[ SPECIALNE KOLO - DVOJITA SANCA ]^nSekund do konca: %i", odpocet_specialchance);
	} else {
		ChatColor(0, "!gSpecialne kolo sa skoncilo!");
		round_DoubleChance = false;

		remove_task(TASK_ROUNDCHANCE);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

// Zaciatok kola (log)
public logevent_round_start()
{
	set_pev(g_iEntBarrier,pev_solid,SOLID_BSP);
	set_pev(g_iEntBarrier,pev_rendermode,kRenderTransColor);
	set_pev(g_iEntBarrier,pev_rendercolor, Float:{ 0.0, 0.0, 0.0 });
	set_pev(g_iEntBarrier,pev_renderamt,Float:{150.0});

	ChatColor(0, "!g<<< ----- VITAJ NA BASEBUILDERI ----- >>>");
	ChatColor(0, "!tPostav si svoj ukryt a zachran sa pred zombies!");
	ChatColor(0, "!yStlac klavesu !gM !yaby si otvoril hlavne menu!");

	client_cmd(0, "spk %s", g_PhaseBuild);
	
	remove_task(TASK_BUILD);

	set_task(1.0, "CountDown", TASK_BUILD,_, _, "a", BUILDTIME);
	count_down = (BUILDTIME-1);

	client_cmd(0, "mp3 stop");

	new nahodne_cislo = random_num(0, sizeof(g_BuildSong)-1);
	client_cmd(0, "mp3 play sound/%s", g_BuildSong[nahodne_cislo]);

	new players[32], num, player;
	get_players(players, num, "e", "CT");
	for (new i = 0; i < num; i++)
	{
		player = players[i];
		g_iWeaponsTaken[player] = false;
	}
}
// Koniec kola (po 00:00)
public logevent_round_end()
{
	g_KoniecKola = true;
	if(!g_CanBuild || !g_boolPrepTime) {
		all_GodMode = true;

		new players[32], num, player;

		if(get_playersnum() > 4) {
			get_players(players, num, "ae", "CT");
			for (new i = 0; i < num; i++)
			{
				player = players[i];

				new reward = 200;
				if(IsUserPremium(player)) { 
					reward = 300; 
				}

				ChatColor(player, "!g%s !yZiskal si !t%i bodov !yza prezitie!", PREFIX, reward);
				p_Body[player] += reward;	
			}
		} else {
			ChatColor(player, "!g%s !yStavitelia nedostali body za prezitie pretoze na servery nie je dostatok hracov!", PREFIX);
		}

		get_players(players, num);
		for (new i = 0; i < num; i++)
		{
			player = players[i];

			p_Revenger[player] = false;
			
			if(g_pCurTeam[player] == g_pTeam[player]) {
				cs_set_user_team(player, (g_pTeam[player] = (g_pTeam[player] == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T)));
			} else {
				g_pTeam[player] = g_pTeam[player] == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T;
			}
		}

		ChatColor(0, "!g%s !yTeamy sa vymenili!", PREFIX);
	}
	remove_task(TASK_BUILD);
}
// Smrt
public ham_Player_Killed(iVictim, iKiller) {
	if(!IsConnected(iVictim) || !IsConnected(iKiller) || iVictim == iKiller)
		return HAM_IGNORED;

	new add_body_victim = IsUserPremium(iVictim) ? 12 : 8;
	new add_body_killer;
	switch(cs_get_user_team(iKiller)) {
		case CS_TEAM_CT: {
			add_body_killer = IsUserPremium(iKiller) ? 25 : 20;
			p_MaxHP[iKiller] += 5;
		}
		case CS_TEAM_T: {
			add_body_killer = IsUserPremium(iKiller) ? 80 : 70;
			client_cmd(0, "spk %s", g_ZombKill);
		}
	}

	p_Revenger[iVictim] = false;

	add_body_victim += 10*p_AllVylepsenia[0][iVictim];
	add_body_killer += 10*p_AllVylepsenia[0][iKiller];

	if(round_DoubleBody) {
		add_body_killer *= 2;
		add_body_victim *= 2;
	}

	p_Body[iVictim] += add_body_victim;
	p_Body[iKiller] += add_body_killer;
	DropItem(iKiller);

	new add_xp_victim = 1 + 2*p_AllVylepsenia[1][iVictim];
	new add_xp_killer = 2 + 2*p_AllVylepsenia[1][iKiller];
	p_XP[iVictim] += add_xp_victim;
	p_XP[iKiller] += add_xp_killer;

	client_print(iVictim, print_center, "+%i bodov | +%i XP", add_body_victim, add_xp_victim);
	client_print(iKiller, print_center, "+%i bodov | +%i XP", add_body_killer, add_xp_killer);

	CheckLevel(iKiller);
	CheckLevel(iVictim);
	if(IsZombie(iVictim)) {
		set_task(4.0, "Respawn_Zombie", iVictim + TASK_RESPAWN);
	} else {
		new nahodne_cislo = random_num(0, 200);
		if(nahodne_cislo == 69) {
			p_Revenger[iVictim] = true;
			set_task(1.5, "Respawn_Revenger", iVictim);
		} else {
			set_task(0.5, "Player_Infection", iVictim);
			set_task(6.0, "Respawn_Zombie", iVictim + TASK_RESPAWN);
		}
	}
	return HAM_IGNORED;
}

public Respawn_Revenger(id) {
	ChatColor(0, "!g%s !yNiekto je Revenger!", PREFIX);
	ChatColor(0, "!g%s !yNiekto je Revenger!", PREFIX);
	ScreenFade(0, 3.0, 250, 10, 0, 200);
	ExecuteHamB(Ham_CS_RoundRespawn, id);
	return PLUGIN_HANDLED;
}

/* INFORMACNE A PRIKAZOVE FUNKCIE*/

public ShowInfo(id) {
    id -= TASK_INFO;
    
    if(!IsConnected(id))
	return PLUGIN_HANDLED;

    if(id <= 0) {
        remove_task(id+TASK_INFO);
        return PLUGIN_CONTINUE;
    }

    if(IsAlive(id)) {
	new cur_hp = get_user_health(id);
	set_hudmessage(0, 245, 50, -1.0, 0.9, 0, 0.0, 1.2, 0.0, 0.0);
	ShowSyncHudMsg(id, HudSync, "Zivot: %i | Body: %i | XP: %i| Level: %i [%s]", cur_hp, p_Body[id], p_XP[id], Level[id], LvlPrefix[Level[id]]);
    }
    return PLUGIN_CONTINUE;
}

public Player_Infection(id) {
	if(!g_KoniecKola)
		cs_set_user_team(id, CS_TEAM_T);
	
	return PLUGIN_HANDLED;
}

public Respawn_Zombie(id)
{
	id -= TASK_RESPAWN;
	
	if (!IsConnected(id) || IsAlive(id) || g_KoniecKola) 
		return PLUGIN_HANDLED;
	
	if (((g_CanBuild || g_boolPrepTime) && cs_get_user_team(id) == CS_TEAM_CT) || IsZombie(id))
	{
		ExecuteHamB(Ham_CS_RoundRespawn, id);

		if (!IsAlive(id))
			set_task(3.0,"Respawn_Zombie",id + TASK_RESPAWN);
	} else if(cs_get_user_team(id) == CS_TEAM_CT && !g_KoniecKola) {
		Player_Infection(id);
		ExecuteHamB(Ham_CS_RoundRespawn, id);
	}
	return PLUGIN_HANDLED;
}

public cmdRespawn(id) {
	if (!IsConnected(id))
		return PLUGIN_HANDLED;
	
	if (((g_CanBuild || g_boolPrepTime) && cs_get_user_team(id) == CS_TEAM_CT) || IsZombie(id) && (get_user_health(id) == p_MaxHP[id] || IsZombie(id) && !IsAlive(id)))
	{
		ExecuteHamB(Ham_CS_RoundRespawn, id);

		if(!IsZombie(id))
			g_iWeaponsTaken[id] = false;

		if(g_boolPrepTime && !IsZombie(id))
			GunsMenu(id);

		if (!IsAlive(id))
			set_task(3.0,"Respawn_Zombie",id+TASK_RESPAWN);
	} else if(!g_CanBuild && !g_boolPrepTime && !IsAlive(id) && cs_get_user_team(id) == CS_TEAM_CT || !g_KoniecKola && !IsAlive(id)) {
		Player_Infection(id);
		ExecuteHamB(Ham_CS_RoundRespawn, id);
	}
	return PLUGIN_HANDLED;
}

public ev_SetTeam(id)
{
	g_friend[id] = read_data(2);
}

public ev_ShowStatus(id)
{
	new name[32], pid = read_data(2);
	
	get_user_name(pid, name, 31);
	new color1 = 0, color2 = 0;
	
	if (get_user_team(pid) == 1) color1 = 255;
	else color2 = 255;
	
	new Float:height=0.30;
	
	if (g_friend[id] == 1)
	{		
		set_hudmessage(color1, 50, color2, -1.0, height, 0, 0.01, 4.0, 0.01, 0.01);
		new nLen, szStatus[512];
		nLen += format(szStatus[nLen], 511-nLen, "Hrac: %s^nBody: %i | XP: %i", name, p_Body[pid], p_XP[pid]);

		nLen += format(szStatus[nLen], 511-nLen, "^n^nSpecialita:");
		if(g_iMarketUpgrades[0][id] || g_iMarketUpgrades[1][id] || g_iMarketUpgrades[2][id] || g_iMarketUpgrades[3][id] || g_iMarketUpgrades[4][id]) {
			for(new i = 0; i < sizeof(MarketUpgrades); i++) {
				if(g_iMarketUpgrades[i][id])
					nLen += format( szStatus[nLen], 511-nLen, "^n%s", MarketUpgrades[i][MarketName]);
			}
		} else {
			nLen += format( szStatus[nLen], 511-nLen, "^nZiadna");
		}

		nLen += format(szStatus[nLen], 511-nLen, "^n^nVylepsenia:");
		if (IsZombie(pid))
		{
			nLen += format(szStatus[nLen], 511-nLen, "^nZivoty %d/200", p_ZMVylepsenia[0][pid]);
			nLen += format(szStatus[nLen], 511-nLen, "^nBrnenie %d/50", p_ZMVylepsenia[1][pid]);
			nLen += format(szStatus[nLen], 511-nLen, "^nGravitacia %d/50", p_ZMVylepsenia[2][pid]);
			nLen += format(szStatus[nLen], 511-nLen, "^nNeviditelnost %d/45", p_ZMVylepsenia[3][pid]);
			nLen += format(szStatus[nLen], 511-nLen, "^nRychlost %d/50", p_ZMVylepsenia[4][pid]);
		} else {
			nLen += format(szStatus[nLen], 511-nLen, "^nPoskodenie %d/50", p_Vylepsenia[0][pid]);
			nLen += format(szStatus[nLen], 511-nLen, "^nMensi recoil %d/50", p_Vylepsenia[1][pid]);
			nLen += format(szStatus[nLen], 511-nLen, "^nPrebijanie %d/50", p_Vylepsenia[2][pid]);
			nLen += format(szStatus[nLen], 511-nLen, "^nKriticky zasah %d/50", p_Vylepsenia[3][pid]);
		}
		
		ShowSyncHudMsg(id, gHudSyncInfo, szStatus);
	}
}

public ev_HideStatus(id)
{
	ClearSyncHud(id, gHudSyncInfo);
}

public CheckLevel(id) {
	if(Level[id] < MaxLevels-1) {
		while(p_XP[id] >= Levels[Level[id]]) {
			Level[id] += 1;
		}
	} 
}

public CmdSay(id) {
	new szArg[192];
	read_args(szArg, charsmax(szArg));
	remove_quotes(szArg);
	return (szArg[0] == '/');
}

/* HOOK */
public hook_on(id) {
	if(!g_CanBuild || IsZombie(id))
		return PLUGIN_HANDLED;

	get_user_origin(id, gHookOrigins[id], 3);
	g_bHook[id] = true;
	set_task(0.1, "hook_task", id, "", 0, "ab");
	hook_task(id);

	return PLUGIN_HANDLED;
}

public hook_task(id) {
	if(!IsConnected(id) || !IsAlive(id))
		remove_hook(id);

	remove_beam(id);
	draw_hook(id);
	new iOrigin[3], Float:fVelocity[3];

	get_user_origin(id, iOrigin);
	new iDistance = get_distance(gHookOrigins[id], iOrigin);
	if (iDistance > 25)
	{
		fVelocity[0] = (gHookOrigins[id][0] - iOrigin[0]) * ( 2.0 * 300 / iDistance);
		fVelocity[1] = (gHookOrigins[id][1] - iOrigin[1]) * ( 2.0 * 300 / iDistance);
		fVelocity[2] = (gHookOrigins[id][2] - iOrigin[2]) * ( 2.0 * 300 / iDistance);
		entity_set_vector(id, EV_VEC_velocity, fVelocity);
	} else {
		entity_set_vector(id, EV_VEC_velocity, Float:{0.0,0.0,0.0});
		remove_hook(id);
	}
}

public draw_hook(id) {
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY );
	write_byte(1); // TE_BEAMENTPOINT
	write_short(id); // Entity index
	write_coord(gHookOrigins[id][0]); // Origin
	write_coord(gHookOrigins[id][1]); // Origin
	write_coord(gHookOrigins[id][2]); // Origin
	write_short(g_iHook); // Sprite index
	write_byte(0); // Start frame
	write_byte(0); // Framerate
	write_byte(100); // Life
	write_byte(10); // Width
	write_byte(0); // Noise
	write_byte(0); // Red
	write_byte(random_num(0, 255)); // Green
	write_byte(random_num(0, 255)); // Blue
	write_byte(250); // Brightness
	write_byte(1); // Speed
	message_end();
}

public remove_hook(id) {
	if( task_exists(id))
		remove_task(id);

	remove_beam(id);
	g_bHook[id] = false;
}

public hook_off(id) {
	remove_hook(id);
	return PLUGIN_HANDLED;
}
public remove_beam(id) {
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(99);
	write_short(id);
	message_end();
}

/* INFORMACNE SPRAVY A CHAT */
// Prefix pred menom (PREMIUM + LEVEL)
public Message_SayText(msgId,msgDest,msgEnt) { 
	new id = get_msg_arg_int(1); 
	
	if(IsConnected(id)) { 
		if(IsUserPremium(id)) { 
			new szChannel[64];
			get_msg_arg_string(2, szChannel, charsmax(szChannel));
		
			if( equal(szChannel, "#Cstrike_Chat_All") ) { 
				formatex(szChannel, charsmax(szChannel), "^4[PREMIUM | %s] ^3%%s1 ^1:  %%s2", LvlPrefix[Level[id]]);
				set_msg_arg_string(2, szChannel);
			} else if( !equal(szChannel, "#Cstrike_Name_Change") ) { 
				format(szChannel, charsmax(szChannel), "^4[PREMIUM | %s] %s", LvlPrefix[Level[id]], szChannel);
				set_msg_arg_string(2, szChannel);
			} 
			return;
		} else {
			new szChannel[64];
			get_msg_arg_string(2, szChannel, charsmax(szChannel));
		
			if( equal(szChannel, "#Cstrike_Chat_All") ) { 
				formatex(szChannel, charsmax(szChannel), "^4[%s] ^3%%s1 ^1:  %%s2", LvlPrefix[Level[id]]);
				set_msg_arg_string(2, szChannel);
			} else if( !equal(szChannel, "#Cstrike_Name_Change") ) { 
				format(szChannel, charsmax(szChannel), "^4[%s] %s", LvlPrefix[Level[id]], szChannel);
				set_msg_arg_string(2, szChannel);
			} 
			return;
		}
	} 
}
// Uprava hlasok na konci kola
public msgRoundEnd(const MsgId, const MsgDest, const MsgEntity) {
	static Message[192];
	get_msg_arg_string(2, Message, 191);
	
	if(equal(Message, "#Hint_you_have_the_bomb") || equal(Message, "#Game_bomb_pickup"))
	{
		strip_user_weapons(MsgEntity);
		give_item(MsgEntity, "weapon_knife");
		return PLUGIN_HANDLED;
	}   

	if(equal(Message, "#Game_bomb_drop"))
		return PLUGIN_HANDLED;
	
	set_dhudmessage(255, 80, 255, -1.0, 0.40, 1, 6.0, 6.0, 0.1, 0.2);
	if (equal(Message, "#Terrorists_Win"))
	{
		show_dhudmessage(0, "Zombie vyhrali!");
		set_msg_arg_string(2, "");
		new nahodne_cislo = random_num(0,1);
		client_cmd(0, "spk %s", g_ZombieWin[nahodne_cislo]);
		return PLUGIN_HANDLED;
	}
	else if (equal(Message, "#Target_Saved") || equal(Message, "#CTs_Win"))
	{
		show_dhudmessage(0, "Stavitelia vyhrali!");
		set_msg_arg_string(2, "");
		new nahodne_cislo = random_num(0,1);
		client_cmd(0, "spk %s", g_BuilderWin[nahodne_cislo]);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}
// Zablokovanie klasickeho audia na konci kola
public msgSendAudio(const MsgId, const MsgDest, const MsgEntity) {
	static szSound[17];
	get_msg_arg_string(2,szSound,16);
	if(equal(szSound[7], "terwin") || equal(szSound[7], "ctwin") || equal(szSound[7], "rounddraw")) return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}
// Odstranenie zobrazovanie Buyzony
public msgStatusIcon(const iMsgId, const iMsgDest, const iPlayer)
{
	if(IsConnected(iPlayer))
	{
		static szMsg[8];
		get_msg_arg_string(2, szMsg, 7);
		
		if(equal(szMsg, "buyzone"))
		{
			set_pdata_int(iPlayer, 268, get_pdata_int(iPlayer, 268) & ~(1<<0));
			return PLUGIN_HANDLED;
		}
	}
	return PLUGIN_CONTINUE;
}

/* AUTOMATICKE PRIPOJENIE DO TYMU */
public message_show_menu(msgid, dest, id)
{
	if (!(!get_user_team(id)))
		return PLUGIN_CONTINUE;
	
	static team_select[] = "#Team_Select";
	static menu_text_code[sizeof team_select];
	get_msg_arg_string(4, menu_text_code, sizeof menu_text_code - 1);
	if (!equal(menu_text_code, team_select))
		return PLUGIN_CONTINUE;
	
	static param_menu_msgid[2];
	param_menu_msgid[0] = msgid;
	set_task(0.1, "task_force_team_join", id, param_menu_msgid, sizeof param_menu_msgid);
	return PLUGIN_HANDLED;
}
public message_vgui_menu(msgid, dest, id)
{
	if (get_msg_arg_int(1) != 2 || !(!get_user_team(id)))
		return PLUGIN_CONTINUE;
	
	static param_menu_msgid[2];
	param_menu_msgid[0] = msgid;
	set_task(0.1, "task_force_team_join", id, param_menu_msgid, sizeof param_menu_msgid);
	return PLUGIN_HANDLED;
}
public task_force_team_join(menu_msgid[], id)
{
	if (get_user_team(id))
		return;
	
	static msg_block;
	msg_block = get_msg_block(menu_msgid[0]);
	set_msg_block(menu_msgid[0], BLOCK_SET);
	engclient_cmd(id, "jointeam", "5");
	engclient_cmd(id, "joinclass", "5");
	set_msg_block(menu_msgid[0], msg_block);
	
	g_pTeam[id] = cs_get_user_team(id);
	g_pCurTeam[id] = cs_get_user_team(id);
}

/* POKRACOVANIE ZACIATKU KOLA - ODPOCET - SCHOVANIE - VYPUSTENIE */
// Odpocet
public CountDown()
{
	count_down--;
	new mins = count_down/60;
	new secs = count_down%60;
	if (count_down>=0) {
		client_print(0, print_center, "Cas na stavbu - %d:%s%d", mins, (secs < 10 ? "0" : ""), secs);
	} else {
		g_CanBuild = false;
		g_boolPrepTime = true;
		count_down = HIDETIME+1;

		set_task(1.0, "task_PrepTime", TASK_PREPTIME,_, _, "a", count_down);
			
		set_hudmessage(0, 255, 50, -1.0, 0.45, 1, 1.0, 4.0, 0.1, 0.2, 1);
		ShowSyncHudMsg(0, g_HudChannel_count, "Cas na schovanie!");
		ChatColor(0, "!gCas na schovanie!");
		ChatColor(0, "!gCas na schovanie!");

		new nahodne_cislo = random_num(0,1);
		client_cmd(0, "spk %s", g_PhaseHide[nahodne_cislo]);

		new players[32], num;
		get_players(players, num);
		for (new i = 0; i < num; i++)
		{
			cmdStopEnt(players[i]);

			ExecuteHamB(Ham_CS_RoundRespawn, players[i]);
		}

		remove_task(TASK_BUILD);
		return PLUGIN_HANDLED;
	}

	new szTimer[32];
	if (count_down > 10) {
		if (mins && !secs) num_to_word(mins, szTimer, 31);
		else if (!mins && secs == 30) num_to_word(secs, szTimer, 31);
		else return PLUGIN_HANDLED;
			
		client_cmd(0, "spk ^"fvox/%s %s remaining^"", szTimer, (mins ? "minutes" : "seconds"));
	} else {
		num_to_word(count_down, szTimer, 31);
		client_cmd(0, "spk ^"fvox/%s^"", szTimer);
	}
	return PLUGIN_CONTINUE;
}
// Schovanie
public task_PrepTime()
{
	count_down--;
	
	if (count_down>=0)
		client_print(0, print_center, "Cas na schovanie - 0:%s%d", (count_down < 10 ? "0" : ""), count_down);
	
	if (0<count_down<11)
	{
		new szTimer[32];
		num_to_word(count_down, szTimer, 31);
		client_cmd(0, "spk ^"fvox/%s^"", szTimer);
	}
	else if (count_down == 0)
	{
		Release_Zombies();
		remove_task(TASK_PREPTIME);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}
// Vypustenie zombies
public Release_Zombies()
{
	g_CanBuild = false;
	g_boolPrepTime = false;
	all_GodMode = false;

	remove_task(TASK_BUILD);
	remove_task(TASK_PREPTIME);

	new players[32], num, player;
	get_players(players, num, "ae", "CT");
	for(new i = 0; i < num; i++)
	{
		player = players[i];

		give_item(player,"weapon_hegrenade");
		new gun_number = g_iWeaponPicked[0][player];
		engclient_cmd(player, MenuWeapons[gun_number][WeaponsEnt]);
	}

	set_pev(g_iEntBarrier,pev_solid,SOLID_NOT);
	set_pev(g_iEntBarrier,pev_renderamt,Float:{ 0.0 });

	set_hudmessage(255, 50, 0, -1.0, 0.45, 1, 1.0, 4.0, 0.1, 0.2, 1);
	ShowSyncHudMsg(0, g_HudChannel_count, "Zombies boli vypusteny!");

	client_cmd(0, "mp3 stop");

	new nahodne_cislo = random_num(0,1);
	client_cmd(0, "spk %s", g_RoundStart[nahodne_cislo]);
}

/* PRIKAZY A MENUS */
// Zablokovanie "kill" v konzole
public fwdClientKill(id) { 
	if(!IsAlive(id)) 
		return FMRES_IGNORED; 

	client_print(id, print_console, "Nemozes sa zabit!"); 
	return FMRES_SUPERCEDE; 
} 

// Zablokovane prikazy + custom
public clcmd_blocked(id) {
	return PLUGIN_HANDLED;
}

public clcmd_dropitem(id) {
	if(cs_get_user_shield(id)) {
		return PLUGIN_CONTINUE;
	}
	return PLUGIN_HANDLED;
}

public clcmd_showcolors(id) {
	console_print(id, "====================================");
	console_print(id, "Meno hraca | STEAM ID | Farba blokov");

	new players[32], num, player, pname[32], pauthid[32];
	get_players(players, num);
	for(new i = 0; i < num; i++)
	{
		player = players[i];

		get_user_authid(player, pauthid, 31);
		get_user_name(player, pname, 31);

		console_print(id, "%s | %s | %s", pname, pauthid, g_ColorName[g_pColor[player]]);
	}
	console_print(id, "====================================");
	return PLUGIN_HANDLED;
} 
// Tlacitko M - Hlavne menu
public clcmd_changeteam(id) {
	MainMenu(id);
	return PLUGIN_HANDLED;
}
// Hlavne menu
public MainMenu(id) {
	new menu = menu_create("Hlavne menu \w(\r/menu\w)", "MainMenu_handle");

	menu_additem(menu, "\yVylepsenia \w(\r/upgrade\w)");
	menu_additem(menu, "\yOdomknut zbrane \w(\r/unlock\w)");
	menu_additem(menu, "\yCierny trh \w(\r/market\w)");
	menu_additem(menu, "\yItemy \w(\r/items\w)^n");
	menu_additem(menu, "Nastavenia");
	menu_additem(menu, "\rPREMIUM");

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public MainMenu_handle(id, menu, item) {
    	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
    	switch(item) {
        	case 0: RozcestnikUpgrades(id);
			case 1: UnlockGuns(id);
			case 2: MarketMenu(id);
			case 3: DropItemMenu(id);
			case 4: NastaveniaMenu(id);
			case 5: show_motd(id, "premium.txt", "PREMIUM Vyhody");
    	}
    	return PLUGIN_HANDLED;
}

// Menu Vylepseni (0)
public RozcestnikUpgrades(id) {
	new menu = menu_create("Vylepsenia", "RozcestnikUpgrades_handle");
    	menu_additem(menu, "\wTakticke vylepsenia^n\d- tykajuce sa hlavne CT postavy^n");
    	menu_additem(menu, "\rBojove vylepsenia^n\d- tykajuce sa hlavne Zombie postavy^n");
    	menu_additem(menu, "\yHerne bonusy^n\d- bonusy ziskavia bodov a XP^n");
    	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public RozcestnikUpgrades_handle(id, menu, item) {
    	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
    	switch(item) {
        	case 0: CTUpgradesMenu(id);
        	case 1: ZMUpgradesMenu(id);
        	case 2: AllUpgradesMenu(id);
    	}
    	return PLUGIN_HANDLED;
}

// Herne vylepsenia (2)
public AllUpgradesMenu(id) {
	new szTitle[64], szItemTitle[128], iAccess;
	formatex(szTitle, charsmax(szTitle), "Herne bonusy^n\wBody: \r%i \d| \wXP: \r%i", p_Body[id], p_XP[id]);
	new menu = menu_create(szTitle, "AllUpgradeMenu_handle");
	for(new i = 0; i < sizeof(UpgradyAll); i++) {
        	formatex(szItemTitle, charsmax(szItemTitle), "\y%s \d(%s)^n\wAktualny level: \r%i/%i^n\wCena: \r%i %s^n", UpgradyAll[i][UpgradeName], UpgradyAll[i][UpgradeDesc], p_AllVylepsenia[i][id], UpgradyAll[i][UpgradeMax], UpgradyAll[i][UpgradeCost] + UpgradyAll[i][UpgradeCost] * p_AllVylepsenia[i][id], (UpgradyAll[i][UpgradePay] ? "XP" : "bodov"));               
			
       		if(UpgradyAll[i][UpgradePay]) {
            		if(p_XP[id] < UpgradyAll[i][UpgradeCost] + UpgradyAll[i][UpgradeCost] * p_AllVylepsenia[i][id] || p_AllVylepsenia[i][id] >= UpgradyAll[i][UpgradeMax]) {
                		iAccess = 1<<31;
            		} else {
                		iAccess = 0;
            		}
        	} else {
            		if(p_Body[id] < UpgradyAll[i][UpgradeCost] + UpgradyAll[i][UpgradeCost] * p_AllVylepsenia[i][id] || p_AllVylepsenia[i][id] >= UpgradyAll[i][UpgradeMax]) {
                		iAccess = 1<<31;
            		} else {
                		iAccess = 0;
            		}
        	}	
		menu_additem(menu, szItemTitle, _, iAccess);
	}
	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public AllUpgradeMenu_handle(id, menu, item) {
    	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
    	if(UpgradyAll[item][UpgradePay]) {
        	p_XP[id] -= UpgradyAll[item][UpgradeCost] + UpgradyAll[item][UpgradeCost] * p_AllVylepsenia[item][id];
    	} else {
		p_Body[id] -= UpgradyAll[item][UpgradeCost] + UpgradyAll[item][UpgradeCost] * p_AllVylepsenia[item][id];
    	}
	p_AllVylepsenia[item][id]++;
	client_cmd(id, "spk %s", g_UpgradeMenuBuy);
	CheckLevel(id);
	AllUpgradesMenu(id);
	return PLUGIN_HANDLED;
}

// Zombie vylepsenia (1)
public ZMUpgradesMenu(id) {
	new szTitle[64], szItemTitle[128], iAccess;
	formatex(szTitle, charsmax(szTitle), "Bojove vylepsenia^n\wBody: \r%i", p_Body[id]);
	new menu = menu_create(szTitle, "ZMUpgradeMenu_handle");
	for(new i = 0; i < sizeof(UpgradyZM); i++) {
        	formatex(szItemTitle, charsmax(szItemTitle), "\y%s \d(%s)^n\wAktualny level: \r%i/%i^n\wCena: \r%i bodov^n", UpgradyZM[i][UpgradeName], UpgradyZM[i][UpgradeDesc], p_ZMVylepsenia[i][id], UpgradyZM[i][UpgradeMax], UpgradyZM[i][UpgradeCost] + UpgradyZM[i][UpgradeCost] * p_ZMVylepsenia[i][id] * 2);        
			
		if(p_Body[id] < UpgradyZM[i][UpgradeCost] + UpgradyZM[i][UpgradeCost] * p_ZMVylepsenia[i][id] * 2 || p_ZMVylepsenia[i][id] >= UpgradyZM[i][UpgradeMax]) {
			iAccess = 1<<31;
		} else {
			iAccess = 0;
		}
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}
	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public ZMUpgradeMenu_handle(id, menu, item) {
    	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
	p_Body[id] -= UpgradyZM[item][UpgradeCost] + UpgradyZM[item][UpgradeCost] * p_ZMVylepsenia[item][id] * 2;
	p_ZMVylepsenia[item][id]++;
	client_cmd(id, "spk %s", g_UpgradeMenuBuy);
	ZMUpgradesMenu(id);
	return PLUGIN_HANDLED;
}

// Stavitel vylepsenia (0)
public CTUpgradesMenu(id) {
	new szTitle[64], szItemTitle[128], iAccess;
	formatex(szTitle, charsmax(szTitle), "Takticke vylepsenia^n\wBody: \r%i", p_Body[id]);
	new menu = menu_create(szTitle, "CTUpgradeMenu_handle");
	for(new i = 0; i < sizeof(UpgradyCT); i++) {
        	formatex(szItemTitle, charsmax(szItemTitle), "\y%s \d(%s)^n\wAktualny level: \r%i/%i^n\wCena: \r%i bodov^n", UpgradyCT[i][UpgradeName], UpgradyCT[i][UpgradeDesc], p_Vylepsenia[i][id], UpgradyCT[i][UpgradeMax], UpgradyCT[i][UpgradeCost] + UpgradyCT[i][UpgradeCost] * p_Vylepsenia[i][id] * 2);        
			
		if(p_Body[id] < UpgradyCT[i][UpgradeCost] + UpgradyCT[i][UpgradeCost] * p_Vylepsenia[i][id] * 2 || p_Vylepsenia[i][id] >= UpgradyCT[i][UpgradeMax]) {
			iAccess = 1<<31;
		} else {
			iAccess = 0;
		}
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}
	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public CTUpgradeMenu_handle(id, menu, item) {
    	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
	p_Body[id] -= UpgradyCT[item][UpgradeCost] + UpgradyCT[item][UpgradeCost] * p_Vylepsenia[item][id] * 2;
	p_Vylepsenia[item][id]++;
	client_cmd(id, "spk %s", g_UpgradeMenuBuy);
	CTUpgradesMenu(id);
	return PLUGIN_HANDLED;
}

/* Vylepsenia nastavenia  a funkcie */
public hook_TakeDamage(id, idinflictor, idattacker, Float:damage, damagebits) {
	if(!IsConnected(id) || !IsConnected(idattacker))
		return HAM_HANDLED;

	if(all_GodMode) // Godmode pocas stavania a na konci kola
		return HAM_SUPERCEDE;

	if(id == idattacker || get_user_team(id) == get_user_team(idattacker))
		return HAM_HANDLED;

	// VYLEPSENIA: Poskodenie
	damage *= 1.00 + 0.01 * p_Vylepsenia[0][idattacker];

	if(g_iMarketUpgrades[1][id]) damage *= 1.22; // MARKET : Extra damage
	else if(g_iMarketUpgrades[0][id]) damage *= 1.11; // MARKET : Damage

        new kriticky_zasah = p_Vylepsenia[3][idattacker]; // VYLEPSENIA: Kriticky zasah
        if(kriticky_zasah > 0) {
            	new random = random_num(1, 100);
            	if(random < kriticky_zasah) {
                	client_print(idattacker, print_center, "Kriticky zasah!");
                	damage *= 1.8;
            	}
        }

	if(p_Revenger[idattacker]) damage *= 4;

        SetHamParamFloat(4, damage);

    	return HAM_HANDLED;
}

// Recoil
public fw_Weapon_PrimaryAttack_Pre(iEnt) {
	new id = pev(iEnt, pev_owner);
	if (p_Vylepsenia[1][id] || g_iMarketUpgrades[2][id]) { // VYLEPSENIA & MARKET : Recoil
		pev(id, pev_punchangle, cl_pushangle[id]);
		return HAM_IGNORED;
	}
	return HAM_IGNORED;
}
public fw_Weapon_PrimaryAttack_Post(iEnt) {
	new id = pev(iEnt, pev_owner);
	if (p_Vylepsenia[1][id] || g_iMarketUpgrades[2][id]) {
		new Float: push[3];
		pev(id, pev_punchangle, push);
		xs_vec_sub(push, cl_pushangle[id], push);

		new Float:calc_recoil = 1.00 - 0.02 * p_Vylepsenia[1][id]; // VYLEPSENIA : Recoil
		if(g_iMarketUpgrades[2][id]) { calc_recoil -= 0.30; } // MARKET : Recoil
		if(calc_recoil < 0.00) { calc_recoil = 0.00; }

		xs_vec_mul_scalar(push, calc_recoil, push);
		xs_vec_add(push, cl_pushangle[id], push);
		set_pev(id, pev_punchangle, push);
		return HAM_IGNORED;
	}
	return HAM_IGNORED;
}

// Prebijanie
public Weapon_Reload(iEnt) {
	new id = get_pdata_cbase(iEnt, m_pPlayer, 4);
	if(get_pdata_int(iEnt, m_fInReload, 4) && (p_Vylepsenia[2][id] || g_iMarketUpgrades[3][id])) {
		new Float:calc_reload = 1.000 - 0.014 * p_Vylepsenia[2][id]; // VYLEPSENIA : Recoil
		if(g_iMarketUpgrades[3][id]) calc_reload -= 0.120; // MARKET : Recoil
		new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, 5) * calc_reload;
		set_pdata_float(id, m_flNextAttack, flNextAttack, 5);
		new iSeconds = floatround(flNextAttack, floatround_ceil);
		Make_BarTime2(id, iSeconds, 100 - floatround((flNextAttack/iSeconds) * 100));
	}
}
public Item_Holster(iEnt) {
	new id = get_pdata_cbase(iEnt, m_pPlayer, 4);
	if(get_pdata_int(iEnt, m_fInReload, 4)  && (p_Vylepsenia[2][id] || g_iMarketUpgrades[3][id]))
		Make_BarTime2(get_pdata_cbase(iEnt, m_pPlayer, 4), 0, 0);
}
// Vytvorime bar, ktory bude zobrazovat za ako dlho sa zbran nabije
Make_BarTime2(id, iSeconds, iPercent) {
	message_begin(MSG_ONE_UNRELIABLE, gmsgBarTime2, _, id);
	write_short(iSeconds);
	write_short(iPercent);
	message_end();
}
// Rychlost pre zombie postavu
public playerResetMaxSpeed(id) {
	if(IsAlive(id)) {
		switch(cs_get_user_team(id)) {
			case CS_TEAM_CT: set_user_maxspeed(id, 250.0);
			case CS_TEAM_T: set_user_maxspeed(id, 250.0 + 5.0 * p_ZMVylepsenia[4][id]); // VYLEPSENIA ZM : Rychlost 
		}
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
} 
// Modely zbrani - ruky ZM, stit a Sialenstvo
public ev_CurWeapon(id) {    
	if(!IsConnected(id) || !IsAlive(id))
		return PLUGIN_HANDLED;

	new pWeapon = get_user_weapon(id);
	// Modely stitu
	if(cs_get_user_shield(id)) {
		set_pev(id, pev_viewmodel2, ZombieShield_v);
		set_pev(id, pev_weaponmodel2, ZombieShield_p);
	} else if(pWeapon == CSW_KNIFE && IsZombie(id)) { // Model zombie ruk
		set_pev(id, pev_viewmodel2, ZombieHands);
		entity_set_string(id, EV_SZ_weaponmodel , ""); 
	}

	if(pWeapon == CSW_KNIFE && p_Revenger[id]) {
		set_pev(id, pev_viewmodel2, chainsaw_viewmodel);
		set_pev(id, pev_weaponmodel2, chainsaw_playermodel);
	}

	if(pWeapon == CSW_C4 || g_CanBuild || g_boolPrepTime || IsZombie(id)) {
		engclient_cmd(id, "weapon_knife"); // Prehodi na ruky, ked je cas na stavbu, schovanie alebo je zombie
	}

	if(g_iMarketBuffs[1][id]) { // MARKET : Sialenstvo
		if(!(NOCLIP_WPN_BS & (1 << pWeapon)))
    		{
        		fm_cs_set_weapon_ammo(get_pdata_cbase(id, m_pActiveItem) , g_MaxClipAmmo[pWeapon]);
    		}
	}
	return PLUGIN_HANDLED;
}

// Nahradenie sounds - Revenger motorovka
public fw_EmitSound(id, channel, const sound[]) {
	if(!IsConnected(id))
		return FMRES_IGNORED;
        
	if(!IsAlive(id) || !p_Revenger[id])
		return FMRES_IGNORED;
        
	for(new i = 0; i < sizeof chainsaw_sounds; i++)
	{
		if(equal(sound, oldknife_sounds[i]))
		{
			emit_sound(id, channel, chainsaw_sounds[i], 1.0, ATTN_NORM, 0, PITCH_NORM);
			return FMRES_SUPERCEDE;
		}
	}
	return FMRES_IGNORED;
}

// Nekonecna municia
public ev_AmmoX(id)
	set_pdata_int(id, 376 + read_data(1), 200, 5);

// Odstrani zo zeme vsetke itemy, ktore sa vyhodia
public ham_WeaponCleaner_Post(iEntity)
	call_think(iEntity);

/* MARKET MENU */
public MarketMenu(id) {
	new menu = menu_create("Cierny trh \w(\r/market\w)", "MarketMenu_handle");

	menu_additem(menu, "Vylepsenia");
	menu_additem(menu, "Itemy");
	menu_additem(menu, "Buffy");
	menu_additem(menu, "Specialne kolo");

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public MarketMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	switch(item) {
		case 0: MarketVylepsenia(id);
		case 1: MarketItemy(id);
		case 2: MarketBuffy(id);
		case 3: SpecialRound(id);
	}
	return PLUGIN_HANDLED;
}
// Vylepsenia
public MarketVylepsenia(id) {
	new szItemTitle[80], iAccess;
	new menu = menu_create("Cierny trh^n\rVylepsenia", "MarketVylepseniaMenu_handle");

	for(new i = 0; i < sizeof(MarketUpgrades); i++) {
        formatex(szItemTitle, charsmax(szItemTitle), (g_iMarketUpgrades[i][id]) ? "\w%s ^n\d- %s ^n\wCena: \y-ZAKUPENE-^n" : "\w%s ^n\d- %s ^n\wCena: \r%i bodov^n", MarketUpgrades[i][MarketName], MarketUpgrades[i][MarketDescription], MarketUpgrades[i][MarketCost]);        
			
		if(g_iMarketUpgrades[i][id] || p_Body[id] <= MarketUpgrades[i][WeaponCost]) {
			iAccess = 1<<31;
		} else {
			iAccess = 0;
		}
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public MarketVylepseniaMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	if(item == 4) {
		remove_task(id + TASK_REGEN);
		set_task(2.0, "Task_HealthRegen", id+TASK_REGEN, _, _, "b");
	}

	p_Body[id] -= MarketUpgrades[item][MarketCost];
	g_iMarketUpgrades[item][id] = true;
	client_cmd(id, "spk %s", g_MarketBuy);
	MarketVylepsenia(id);
	return PLUGIN_HANDLED;
}
// TASK : Regeneracia
public Task_HealthRegen(id) {
	id -= TASK_REGEN;
	
	new iGetUserHealth = get_user_health(id);
		
	if(iGetUserHealth < p_MaxHP[id] && !g_iMarketBuffs[0][id])
	{
		new calc_hp = ((iGetUserHealth / 100) * 5) + 5;
		set_user_health(id, iGetUserHealth + calc_hp);

		iGetUserHealth = get_user_health(id);
			
		if(iGetUserHealth > p_MaxHP[id])
			set_user_health(id, p_MaxHP[id]);
	}
}
// Itemy
public MarketItemy(id) {
	new szItemTitle[100], iAccess;
	new menu = menu_create("Cierny trh^n\rItemy", "MarketItemyMenu_handle");

	for(new i = 0; i < sizeof(MarketItems); i++) {
        	formatex(szItemTitle, charsmax(szItemTitle), (g_iMarketItems[i][id]) ? "\w%s^n\d- %s^n\wCena: \y-ZAKUPENE-^n" : "\w%s^n\d- %s^n\wCena: \r%i bodov^n", MarketItems[i][SpecialName], MarketItems[i][SpecialDesc], MarketItems[i][SpecialPrice]);        
			
		if(g_iMarketItems[i][id] || p_Body[id] <= MarketItems[i][SpecialPrice] || MarketItems[i][ForTeam] != cs_get_user_team(id)) {
			iAccess = 1<<31;
		} else {
			iAccess = 0;
		}
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public MarketItemyMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	p_Body[id] -= MarketItems[item][SpecialPrice];
	g_iMarketItems[item][id] = true;
	client_cmd(id, "spk %s", g_MarketBuy);
	switch(item) {
		case 0: give_item(id, "item_assaultsuit");
		case 1: give_item(id, "weapon_flashbang");
		case 2: give_item(id, "weapon_hegrenade");
		case 3: { 
			give_item(id, "weapon_shield"); 
			ev_CurWeapon(id);
		}
	}
	MarketItemy(id);
	return PLUGIN_HANDLED;
}
// Buffy
public MarketBuffy(id) {
	new szItemTitle[100], iAccess;
	new menu = menu_create("Cierny trh^n\rBuffy", "MarketBuffyMenu_handle");

	for(new i = 0; i < sizeof(MarketBuffs); i++) {
        	formatex(szItemTitle, charsmax(szItemTitle), (g_iMarketBuffs[i][id]) ? "\w%s^n\d- %s^n\wCena: \y-ZAKUPENE-^n" : "\w%s^n\d- %s^n\wCena: \r%i bodov^n", MarketBuffs[i][SpecialName], MarketBuffs[i][SpecialDesc], MarketBuffs[i][SpecialPrice]);        
			
		if(g_iMarketBuffs[i][id] || p_Body[id] <= MarketBuffs[i][SpecialPrice] || MarketBuffs[i][ForTeam] != cs_get_user_team(id)) {
			iAccess = 1<<31;
		} else {
			iAccess = 0;
		}
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}
public MarketBuffyMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	p_Body[id] -= MarketBuffs[item][SpecialPrice];
	g_iMarketBuffs[item][id] = true;
	client_cmd(id, "spk %s", g_MarketBuy);
	switch(item) {
		case 0: set_task(2.0, "Task_MutaciaRegen", id+TASK_MUTACIA, _, _, "b");
		case 1: set_task(30.0, "Remove_NoReload", id+TASK_NORELOAD);
	}
	MarketBuffy(id);
	return PLUGIN_HANDLED;
}
// TASK : Mutacia
public Task_MutaciaRegen(id) {
	id -= TASK_MUTACIA;
	
	new iGetUserHealth = get_user_health(id);
		
	if(iGetUserHealth < p_MaxHP[id] && cs_get_user_team(id) & CS_TEAM_T)
	{
		new calc_hp = ((iGetUserHealth / 100) * 20) + 5;
		set_user_health(id, iGetUserHealth + calc_hp);

		iGetUserHealth = get_user_health(id);
			
		if(iGetUserHealth > p_MaxHP[id])
			set_user_health(id, p_MaxHP[id]);
	}
}
// TASK : Sialenstvo
public Remove_NoReload(id) {
	id -= TASK_NORELOAD;
	g_iMarketBuffs[1][id] = false;
}

/* ODOMKNUT ZBRANE MENU */ 
public UnlockGuns(id) {
	new menu = menu_create("Odomknut zbrane \w(\r/unlock\w)", "UnlockMenu_handle");

	menu_additem(menu, "Utocne pusky");
	menu_additem(menu, "Pistole");
	menu_additem(menu, "\rSpecialne");

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public UnlockMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	switch(item) {
		case 0: GunsPuskyMenu(id, 0);
		case 1: GunsPistoleMenu(id);
		case 2: {
			if(g_iDropItems[1][id] == 1) {
				ChatColor(id, "!g%s !yZial tato moznost zatial dostupna!", PREFIX);
			} else {
				ChatColor(id, "!g%s !ySpecialne zbrane zatial nie su dostupne! Musis !tziskat kluc techniky!y pre ich odomknutie!", PREFIX);
			}
		}
	}
	return PLUGIN_HANDLED;
}
// Utocne pusky
public GunsPuskyMenu(id, pagenum) {
	new szItemTitle[64], iAccess;
	new menu = menu_create("Odokmnut zbrane^n\rUtocne pusky^n\wStrana:\d", "GunsPuskyMenu_handle");

	for(new i = 1; i < sizeof(MenuWeapons); i++) {
        	formatex(szItemTitle, charsmax(szItemTitle), (g_iWeaponsUnlocked[i][id] == 1) ? "\w%s \dCena: \y-ODOMKNUTE-" : "\w%s \dCena: \r%i bodov", MenuWeapons[i][WeaponName], MenuWeapons[i][WeaponCost]);        
			
		if(g_iWeaponsUnlocked[i][id] == 1 || p_Body[id] <= MenuWeapons[i][WeaponCost]) {
			iAccess = 1<<31;
		} else {
			iAccess = 0;
		}
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}

	menu_setprop(menu, MPROP_BACKNAME, "Zpet");
	menu_setprop(menu, MPROP_NEXTNAME, "Dalsie");
	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, pagenum);
	return PLUGIN_HANDLED;
}
public GunsPuskyMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	p_Body[id] -= MenuWeapons[item][WeaponCost];
	g_iWeaponsUnlocked[item+1][id] = 1;
	client_cmd(id, "spk %s", g_MenuUnlock);

	if(item > 6) GunsPuskyMenu(id, 1);
	else GunsPuskyMenu(id, 0);
	return PLUGIN_HANDLED;
}
// Pistole
public GunsPistoleMenu(id) {
	new szItemTitle[64], iAccess;
	new menu = menu_create("Odokmnut zbrane^n\rPistole", "GunsPistoleMenu_handle");

	for(new i = 1; i < sizeof(SecondaryWeapons); i++) {
        	formatex(szItemTitle, charsmax(szItemTitle), (g_iSecondaryUnlocked[i][id]) ? "\w%s \dCena: \y-ODOMKNUTE-" : "\w%s \dCena: \r%i bodov", SecondaryWeapons[i][WeaponName], SecondaryWeapons[i][WeaponCost]);        
			
		if(g_iSecondaryUnlocked[i][id] == 1 || p_Body[id] <= SecondaryWeapons[i][WeaponCost]) {
			iAccess = 1<<31;
		} else {
			iAccess = 0;
		}
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}

	menu_setprop(menu, MPROP_BACKNAME, "Zpet");
	menu_setprop(menu, MPROP_NEXTNAME, "Dalsie");
	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public GunsPistoleMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	p_Body[id] -= SecondaryWeapons[item][WeaponCost];
	g_iSecondaryUnlocked[item+1][id] = 1;
	client_cmd(id, "spk %s", g_MenuUnlock);
	GunsPistoleMenu(id); 
	return PLUGIN_HANDLED;
}

/* VYBER ZBRANI */
public GunsMenu(id) {
	if(IsZombie(id) || !g_boolPrepTime || g_iWeaponsTaken[id])
		return PLUGIN_HANDLED;

	if(!g_iWeaponPicked[0][id]) {
		guns_primary(id);
		return PLUGIN_HANDLED;
	}

	new menu = menu_create("Vyber si zbrane \w(\r/guns\w)", "GunsMenu_handle");

	menu_additem(menu, "Nove zbrane");
	menu_additem(menu, "Posledne zbrane");

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public GunsMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
	switch(item) {
		case 0: guns_primary(id);
		case 1: give_guns(id);
	}
	return PLUGIN_HANDLED;
}
// Pridame posledne vybrane zbrane
public give_guns(id) {
	if(!IsConnected(id) || !IsAlive(id) || !g_iWeaponPicked[0][id])
		return PLUGIN_HANDLED;

	new gun_number = g_iWeaponPicked[0][id];
	give_item(id, MenuWeapons[gun_number][WeaponsEnt]);
	new pistol_number = g_iWeaponPicked[1][id];
	give_item(id, SecondaryWeapons[pistol_number][WeaponsEnt]);
	return PLUGIN_HANDLED;
}
// Vyber zbrani - primarne
public guns_primary(id) {
	new szItemTitle[32], iAccess;
	new menu = menu_create("Vyber si zbrane \r[UTOCNE PUSKY]^n\wStrana:\d", "GunsPrimaryMenu_handle");
	for(new i = 1; i < sizeof(MenuWeapons); i++) {
        	formatex(szItemTitle, charsmax(szItemTitle), (g_iWeaponsUnlocked[i][id] == 1) ? "\w%s" : "\d%s", MenuWeapons[i][WeaponName]);        
			
		if(!(g_iWeaponsUnlocked[i][id] == 1)) {
			iAccess = 1<<31;
		} else {
			iAccess = 0;
		}
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}

	menu_setprop(menu, MPROP_BACKNAME, "Zpet");
	menu_setprop(menu, MPROP_NEXTNAME, "Dalsie");
	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public GunsPrimaryMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
	g_iWeaponPicked[0][id] = item+1;
	guns_secondary(id);
	g_iWeaponsTaken[id] = true;
	return PLUGIN_HANDLED;
}
// Vyber zbrani - sekundarne
public guns_secondary(id) {
	new szItemTitle[32], iAccess;
	new menu = menu_create("Vyber si zbrane \r[PISTOLE]", "GunsSecondaryMenu_handle");
	for(new i = 1; i < sizeof(SecondaryWeapons); i++) {
        	formatex(szItemTitle, charsmax(szItemTitle), (g_iSecondaryUnlocked[i][id] == 1) ? "\w%s" : "\d%s", SecondaryWeapons[i][WeaponName]);        
			
		if(!(g_iSecondaryUnlocked[i][id] == 1)) {
			iAccess = 1<<31;
		} else {
			iAccess = 0;
		}
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public GunsSecondaryMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
	g_iWeaponPicked[1][id] = item+1;
	give_guns(id);
	return PLUGIN_HANDLED;
}

/* PADANIE ITEMOV */
public DropItemMenu(id) {
	new menu = menu_create("Itemy \w(\r/items\w)", "DropItemMenu_handle");

	menu_additem(menu, "\rLevely^n");

	menu_additem(menu, (g_iDropItems[0][id] == 1) ? "Zatmenie \y-ZISKANE-" : "Zatmenie");
	menu_additem(menu, (g_iDropItems[1][id] == 1) ? "Kluc techniky \y-ZISKANE-" : "Kluc techniky");
	menu_additem(menu, (g_iDropItems[2][id] == 1) ? "Aurora \y-ZISKANE-" : "Aurora");

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public DropItemMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
	switch(item) {
		case 0: {
			static tempstring[100], motd[1024];
			format(motd,charsmax(motd), "<html><body bgcolor='#000'><font size='2' face='verdana' color='FFFFFF'><center>");

			format(tempstring,charsmax(tempstring), "<h1 style='color: green;'>LEVELY</h1><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "<i>Tvoj aktualny level je: <b>%i</b></i><br><br>", Level[id]);
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "<b>Kazdy dalsi level dostanes:</b><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "+40 HP k Zombie postave<br>+5 HP k Stavitelskej postave<br>Specialny prefix pred meno");
			add(motd,charsmax(motd), tempstring);

			add(motd,charsmax(motd), "</center></font></body></html>");

			show_motd(id, motd, "Item: Zatmenie");
		}
		case 1: {
			static tempstring[100], motd[1024];
			format(motd,charsmax(motd), "<html><body bgcolor='#000'><font size='2' face='verdana' color='FFFFFF'><center>");

			format(tempstring,charsmax(tempstring), "<h1 style='color: gold;'>ZATMENIE</h1><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "<i>Sanca na ziskanie tohto itemu je: 1 ku 1000.</i><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), (g_iDropItems[0][id] == 1) ? "<font color='green'>Vlastnis item zatmenie!</font><br><br>" : "<font color='red'>Nevlastnis item zatmenie!</font><br><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "<b>V pripade ze ziskas tento item dostanes:</b><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "+200 HP k Zombie postave<br>+25 HP k Stavitelskej postave<br>+2 Levely k Zivotu<br>+2 Levely ku Gravitacii<br>+2 Levely k Mensiemu recoilu");
			add(motd,charsmax(motd), tempstring);

			add(motd,charsmax(motd), "</center></font></body></html>");

			show_motd(id, motd, "Item: Zatmenie");
		}
		case 2: {
			static tempstring[100], motd[1024];
			format(motd,charsmax(motd), "<html><body bgcolor='#000'><font size='2' face='verdana' color='FFFFFF'><center>");

			format(tempstring,charsmax(tempstring), "<h1 style='color: blue;'>KLUC TECHNIKY</h1><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "<i>Sanca na ziskanie tohto itemu je: 1 ku 500.</i><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), (g_iDropItems[1][id] == 1) ? "<font color='green'>Vlastnis item Kluc techniky!</font><br><br>" : "<font color='red'>Nevlastnis item Kluc techniky!</font><br><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "<b>V pripade ze ziskas tento item dostanes:</b><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "Pristup ku specialnym zbraniam<br>+ 4 Levely k Poskodeniu<br>+ 4 Levely ku Kritickemu zasahu");
			add(motd,charsmax(motd), tempstring);

			add(motd,charsmax(motd), "</center></font></body></html>");

			show_motd(id, motd, "Item: Kluc techniky");
		}
		case 3: {
			static tempstring[200], motd[1024];
			format(motd,charsmax(motd), "<html><body bgcolor='#000'><font size='2' face='verdana' color='FFFFFF'><center>");

			format(tempstring,charsmax(tempstring), "<h1 style='color: yellow;'>AURORA</h1><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "<i>Sanca na ziskanie tohto itemu je: 1 ku 1500.</i><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), (g_iDropItems[2][id] == 1) ? "<font color='green'>Vlastnis item Aurora!</font><br><br>" : "<font color='red'>Nevlastnis item Aurora!</font><br><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "<b>V pripade ze ziskas tento item dostanes:</b><br>");
			add(motd,charsmax(motd), tempstring);

			format(tempstring,charsmax(tempstring), "Specialnu auru okolo Stavitelskej postavy<br>+ 5 Levelov k Rychlosti<br>+ 5 Levelov k Neviditelnosti<br>+ 5 Levelov k Rychlejsiemu prebijaniu");
			add(motd,charsmax(motd), tempstring);

			add(motd,charsmax(motd), "</center></font></body></html>");

			show_motd(id, motd, "Item: Aurora");
		}
	}
	DropItemMenu(id);
	return PLUGIN_HANDLED;
}

public DropItem(id) {
	new nahodne_cislo = random_num(0,3);

	switch(nahodne_cislo) {
		case 0: DropZatmenie(id);
		case 1: DropKluc(id);
		case 2: DropAurora(id);
		case 3: DropCasual(id);
	}
}

public DropCasual(id) {
	new nahodne_cislo;
	if(round_DoubleChance) {
		nahodne_cislo = random_num(0,150);
	} else {
		nahodne_cislo = random_num(0,200);
	}
	new nahodny_dropVylepsenia = random_num(0,4);

	switch(nahodne_cislo) {
		case 99: {
			if(cs_get_user_team(id) == CS_TEAM_T || g_iMarketUpgrades[nahodny_dropVylepsenia][id])
				return PLUGIN_HANDLED;

			g_iMarketUpgrades[nahodny_dropVylepsenia][id] = true;

			if(nahodny_dropVylepsenia == 4) {
				remove_task(id + TASK_REGEN);
				set_task(2.0, "Task_HealthRegen", id+TASK_REGEN, _, _, "b");
			}

			ScreenFade(0, 3.0, 10, 0, 88, 155);
			client_cmd(0, "spk %s", g_DropItem);

			set_dhudmessage(0, 200, 0, -1.0, 0.40, 0, 4.0, 6.0, 0.1, 0.2);
			show_dhudmessage(id, "Ziskal si item: %s!", MarketUpgrades[nahodny_dropVylepsenia][MarketName]);

			for(new i = 0; i < 3;i++)
				ChatColor(0, "!gNiekto ziskal item: !t%s!g!", MarketUpgrades[nahodny_dropVylepsenia][MarketName]);

			for(new i = 0; i < 4;i++)
				ChatColor(id, "!gZiskal si item: !t%s!g!", MarketUpgrades[nahodny_dropVylepsenia][MarketName]);

		}
		case 1: {
			if(cs_get_user_team(id) == CS_TEAM_CT || g_iMarketItems[3][id])
				return PLUGIN_HANDLED;

			g_iMarketItems[3][id] = true;

			give_item(id, "weapon_shield"); 
			ev_CurWeapon(id);

			ScreenFade(0, 3.0, 10, 0, 88, 155);
			client_cmd(0, "spk %s", g_DropItem);

			set_dhudmessage(0, 200, 0, -1.0, 0.40, 0, 4.0, 6.0, 0.1, 0.2);
			show_dhudmessage(id, "Ziskal si item: Stit mutacie!");

			for(new i = 0; i < 3;i++)
				ChatColor(0, "!gNiekto ziskal item: !tStit mutacie!g!");

			for(new i = 0; i < 4;i++)
				ChatColor(id, "!gZiskal si item: !tStit mutacie!g!");
		}
	}
	return PLUGIN_HANDLED;
}

public DropZatmenie(id) {
	new nahodne_cislo;
	
	if(round_DoubleChance) {
		nahodne_cislo = random_num(0,900);
	} else {
		nahodne_cislo = random_num(0,1000);
	}

	switch(nahodne_cislo) {
        	case 120: {
			if(g_iDropItems[0][id] == 1)
				return PLUGIN_HANDLED;

			set_dhudmessage(100, 80, 40, -1.0, 0.40, 1, 8.0, 12.0, 0.1, 0.2);
			show_dhudmessage(id, "Ziskal si ZATMENIE!");

            		ScreenFade(0, 8.0, 10, 0, 0, 160);
			ScreenShake(0, 40.0, 8.0, 5.0);
			client_cmd(0, "spk %s", g_DropItem);

			for(new i = 0; i < 3;i++)
				ChatColor(0, "!gNiekto ziskal !tZATMENIE!g!");

			for(new i = 0; i < 4;i++)
				ChatColor(id, "!gZiskal si !tZATMENIE!g!");

			g_iDropItems[0][id] = 1;
			
			p_ZMVylepsenia[0][id] += 2;
			p_ZMVylepsenia[2][id] += 2;
			p_Vylepsenia[1][id] += 2;

			if(p_ZMVylepsenia[0][id] > UpgradyZM[0][UpgradeMax]) p_ZMVylepsenia[0][id] = UpgradyZM[0][UpgradeMax];
			if(p_ZMVylepsenia[2][id] > UpgradyZM[2][UpgradeMax]) p_ZMVylepsenia[2][id] = UpgradyZM[2][UpgradeMax];
			if(p_Vylepsenia[1][id] > UpgradyCT[1][UpgradeMax]) p_Vylepsenia[1][id] = UpgradyCT[1][UpgradeMax];
		} 
	}
	return PLUGIN_HANDLED;
}

public DropKluc(id) {
	new nahodne_cislo = random_num(0,500);
	switch(nahodne_cislo) {
		case 488: {
			if(g_iDropItems[1][id] == 1)
				return PLUGIN_HANDLED;

			set_dhudmessage(100, 80, 40, -1.0, 0.40, 1, 8.0, 12.0, 0.1, 0.2);
			show_dhudmessage(id, "Ziskal si KLUC TECHNIKY!");

			ScreenFade(0, 9.0, 0, 150, 0, 140);
			ScreenShake(0, 30.0, 7.0, 5.0);
			client_cmd(0, "spk %s", g_DropItem);

			for(new i = 0; i < 3;i++)
				ChatColor(0, "!gNiekto ziskal !tKLUC TECHNIKY!g!");

			for(new i = 0; i < 4;i++)
				ChatColor(id, "!gZiskal si !tKLUC TECHNIKY!g!");

			g_iDropItems[1][id] = 1;

			p_Vylepsenia[0][id] += 4;
			p_Vylepsenia[3][id] += 4;

			if(p_Vylepsenia[0][id] > UpgradyCT[0][UpgradeMax]) p_Vylepsenia[0][id] = UpgradyCT[0][UpgradeMax];
			if(p_Vylepsenia[3][id] > UpgradyCT[3][UpgradeMax]) p_Vylepsenia[3][id] = UpgradyCT[3][UpgradeMax];
		}
	}
	return PLUGIN_HANDLED;
}

public DropAurora(id) {
	new nahodne_cislo;
	
	if(round_DoubleChance) {
		nahodne_cislo = random_num(0,1200);
	} else {
		nahodne_cislo = random_num(0,1500);
	}

	switch(nahodne_cislo) {
		case 991: {
			if(g_iDropItems[2][id] == 1)
				return PLUGIN_HANDLED;

			set_dhudmessage(190, 180, 40, -1.0, 0.40, 1, 8.0, 12.0, 0.1, 0.2);
			show_dhudmessage(id, "Ziskal si AURORU!");

			ScreenFade(0, 12.0, 0, 80, 120, 150);
			ScreenShake(0, 30.0, 12.0, 5.0);
			client_cmd(0, "spk %s", g_DropItem);

			for(new i = 0; i < 3;i++)
				ChatColor(0, "!gNiekto ziskal !tAURORU!g!");

			for(new i = 0; i < 4;i++)
				ChatColor(id, "!gZiskal si !tAURORU!g!");

			g_iDropItems[2][id] = 1;

			p_ZMVylepsenia[4][id] += 5;
			p_ZMVylepsenia[3][id] += 5;
			p_Vylepsenia[2][id] += 5;

			if(p_ZMVylepsenia[4][id] > UpgradyZM[4][UpgradeMax]) p_ZMVylepsenia[4][id] = UpgradyZM[4][UpgradeMax];
			if(p_ZMVylepsenia[3][id] > UpgradyZM[3][UpgradeMax]) p_ZMVylepsenia[3][id] = UpgradyZM[3][UpgradeMax];
			if(p_Vylepsenia[2][id] > UpgradyCT[2][UpgradeMax]) p_Vylepsenia[2][id] = UpgradyCT[2][UpgradeMax];
		}
	}
	return PLUGIN_HANDLED;
}

/* NASTAVENIA */
public NastaveniaMenu(id) {
	static szItemTitle[40];
	new menu = menu_create("Nastavenia", "NastaveniaMenu_handle");

	menu_additem(menu, "Respawn");

	menu_additem(menu, (g_Settings3D[id]) ? "3D Pohlad \y[ZAPNUTY]" : "3D Pohlad \r[VYPNUTY]");

	//menu_additem(menu, (g_SettingsSound[id]) ? "Hudba pri stavani \y[ZAPNUTY]" : "Hudba pri stavani \r[VYPNUTY]");

	formatex(szItemTitle, charsmax(szItemTitle), "Farba blokov \d[%s]", g_ColorName[g_pColor[id]]);
	menu_additem(menu, szItemTitle);

	menu_additem(menu, "Statistiky hracov");

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public NastaveniaMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}

	switch(item) {
		case 0: {
			cmdRespawn(id);
			return PLUGIN_HANDLED;
		}
		case 1: { 
			if(g_Settings3D[id]) {
				g_Settings3D[id] = false;
				set_view(id, CAMERA_NONE);
			} else {
				g_Settings3D[id] = true;
				set_view(id, CAMERA_3RDPERSON);
			}
		}
		case 2: {
			ColorsMenu(id);
			return PLUGIN_HANDLED;
		}
		case 3: {
			StatistikyHracovMenu(id);
			return PLUGIN_HANDLED;
		}
	}
	NastaveniaMenu(id);
	return PLUGIN_HANDLED;
}

public ColorsMenu(id) {
	static szItemTitle[32], iAccess;
	new menu = menu_create("Farba blokov^n\wStrana:\d", "ColorsMenu_handle");

	for(new i = 0; i < sizeof(g_ColorName); i++) {
		if(g_pColor[id] == i) {
			iAccess = 1<<31;
			formatex(szItemTitle, charsmax(szItemTitle), "\r%s", g_ColorName[i]);   
		} else {
			iAccess = 0;
			formatex(szItemTitle, charsmax(szItemTitle), "%s", g_ColorName[i]);     
		}   
			
		menu_additem(menu, szItemTitle, _, iAccess);
	}

	menu_setprop(menu, MPROP_BACKNAME, "Zpet");
	menu_setprop(menu, MPROP_NEXTNAME, "Dalsie");
	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public ColorsMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}

	g_pColor[id] = item;
	ChatColor(id, "!g%s !yFarba tvojich blokov bola nastavena na: !t%s!y!", PREFIX, g_ColorName[g_pColor[id]]);
	return PLUGIN_HANDLED;
}

public StatistikyHracovMenu(id) {
	new menu = menu_create("Statistiky hracov^n\d", "StatistikyHracovMenu_handle");

	new players[32], pnum, tempid;
	new szName[32], szUserId[10];
	get_players(players, pnum);

	for(new i; i<pnum; i++)
	{
		tempid = players[i];

		get_user_name(tempid, szName, charsmax(szName));
		formatex(szUserId, charsmax(szUserId), "%d", get_user_userid(tempid));

		menu_additem(menu, szName, szUserId, 0);
	}

	menu_setprop(menu, MPROP_BACKNAME, "Zpet");
	menu_setprop(menu, MPROP_NEXTNAME, "Dalsie");
	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public StatistikyHracovMenu_handle(id, menu, item) {
    if(item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new szData[6], szName[64];
    new _access, item_callback;

    menu_item_getinfo(menu, item, _access, szData,charsmax(szData), szName,charsmax(szName), item_callback);

    new userid = str_to_num(szData);

    new player = find_player("k", userid);
	
    if(player)
    {
		new tempstring[80], motd[1024];
		format(motd,charsmax(motd), "<html><body bgcolor='#000'><font size='2' face='verdana' color='FFFFFF'><center>");

		format(tempstring,charsmax(tempstring), "<h2>Statistiky hraca<br>%s</h2><br>", szName);
		add(motd,charsmax(motd), tempstring);

		format(tempstring,charsmax(tempstring), "<font size='3'>Specialne itemy:</font><br>");
		add(motd,charsmax(motd), tempstring);

		if(g_iDropItems[0][player]) {
			format(tempstring,charsmax(tempstring), "<font color='green'>Zatmenie</font><br>");
			add(motd,charsmax(motd), tempstring);
		}
		if(g_iDropItems[1][player]) {
			format(tempstring,charsmax(tempstring), "<font color='blue'>Kluc techniky</font><br>");
			add(motd,charsmax(motd), tempstring);
		}
		if(g_iDropItems[2][player]) {
			format(tempstring,charsmax(tempstring), "<font color='red'>Aurora</font><br>");
			add(motd,charsmax(motd), tempstring);
		}

		format(tempstring,charsmax(tempstring), "<br><br><font size='3'>Vylepsenia:</font><br><br>");
		add(motd,charsmax(motd), tempstring);

		format(tempstring,charsmax(tempstring), "<b>Takticke vylepsenia</b><br><br>");
		add(motd,charsmax(motd), tempstring);

		for(new i = 0; i < sizeof(UpgradyCT); i++) {
			format(tempstring,charsmax(tempstring), "%s <font color='green'>%i/%i</font><br>", UpgradyCT[i][UpgradeName], p_Vylepsenia[i][player], UpgradyCT[i][UpgradeMax]);
			add(motd,charsmax(motd), tempstring);
		}

		format(tempstring,charsmax(tempstring), "<br><b>Bojove vylepsenia</b><br><br>");
		add(motd,charsmax(motd), tempstring);

		for(new i = 0; i < sizeof(UpgradyZM); i++) {
			format(tempstring,charsmax(tempstring), "%s <font color='green'>%i/%i</font><br>", UpgradyZM[i][UpgradeName], p_ZMVylepsenia[i][player], UpgradyZM[i][UpgradeMax]);
			add(motd,charsmax(motd), tempstring);
		}

		format(tempstring,charsmax(tempstring), "<br><b>Herne bonusy</b><br><br>");
		add(motd,charsmax(motd), tempstring);

		for(new i = 0; i < sizeof(UpgradyAll); i++) {
			format(tempstring,charsmax(tempstring), "%s <font color='green'>%i/%i</font><br>", UpgradyAll[i][UpgradeName], p_AllVylepsenia[i][player], UpgradyAll[i][UpgradeMax]);
			add(motd,charsmax(motd), tempstring);
		}

		add(motd,charsmax(motd), "</center></font></body></html>");

		format(tempstring,charsmax(tempstring), "Statistiky hraca %s", szName);
		show_motd(id, motd, tempstring);
    }

    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

/* SPECIALNE KOLA */
public SpecialRound(id) {
	new iAccess;
	new menu = menu_create("Cierny trh^n\rSpecialne kolo", "SpecialRoundMenu_handle");

	if(p_XP[id] < 500) {
		iAccess = 1<<31;
	} else {
		iAccess = 0;
	}

	menu_additem(menu, "\wDvojite body^n\d- 2x viac bodov^n\wCena: \r500 XP^n", _, iAccess);
	menu_additem(menu, "\wDvojita sanca^n\d- 2x sanca na ziskanie itemu^n\wCena: \r500 XP^n", _, iAccess);

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public SpecialRoundMenu_handle(id, menu, item) {
	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}

	if(round_DoubleBody || round_DoubleChance) {
		ChatColor(id, "!g%s !yPrave prebieha specialne kolo! Musis pockat pokial skonci!", PREFIX);
		return PLUGIN_HANDLED;
	}

	switch(item) {
		case 0: {
			round_DoubleBody = true;
			odpocet_specialbody = 300;
			set_task(1.0, "SpecialRoundBody", TASK_ROUNDBODY,_, _, "a", odpocet_specialbody);

			for(new i = 0; i < 4;i++)
				ChatColor(0, "!gNejaky hrac spustil event !tDvojite body!g!");
		}
		case 1: {
			round_DoubleChance = true;
			odpocet_specialchance = 300;
			set_task(1.0, "SpecialRoundChance", TASK_ROUNDCHANCE,_, _, "a", odpocet_specialchance);

			for(new i = 0; i < 4;i++)
				ChatColor(0, "!gNejaky hrac spustil event !tDvojita sanca!g!");
		}
	}
	p_XP[id] -= 500;
	return PLUGIN_HANDLED;
}

/* POHYB Z BLOKMI */
public fw_CmdStart(id, uc_handle, randseed)
{
	if (!IsConnected(id) || !IsAlive(id))
		return FMRES_HANDLED;

	static button, oldbutton;
	button = get_uc(uc_handle , UC_Buttons);
	oldbutton = pev(id, pev_oldbuttons);

	if(button & IN_USE && !(oldbutton & IN_USE) && !g_iOwnedEnt[id]) {
		cmdGrabEnt(id);
		return FMRES_HANDLED;
	}
	else if(oldbutton & IN_USE && !(button & IN_USE) && g_iOwnedEnt[id]) {
		cmdStopEnt(id);
		return FMRES_HANDLED;
	}

	if(!(oldbutton & IN_RELOAD) && (button & IN_RELOAD))
	{
		hook_on(id);
		return FMRES_HANDLED;
	}
	else if((oldbutton & IN_RELOAD) && !(button & IN_RELOAD))
	{
		hook_off(id);
		return FMRES_HANDLED;
	}


	if (!g_iOwnedEnt[id] || !is_valid_ent(g_iOwnedEnt[id]))
		return FMRES_HANDLED;

	new buttons = pev(id, pev_button);
	if (buttons & IN_ATTACK)
	{
		g_fEntDist[id] += 2.0;
		
		if (g_fEntDist[id] > 960.0)
			g_fEntDist[id] = 960.0;
	
	}
	else if (buttons & IN_ATTACK2)
	{
		g_fEntDist[id] -= 2.0;
			
		if (g_fEntDist[id] < 50.0)
			g_fEntDist[id] = 50.0;
			
	}
	
	new iOrigin[3], iLook[3], Float:fOrigin[3], Float:fLook[3], Float:vMoveTo[3], Float:fLength;
	    
	get_user_origin(id, iOrigin, 1);
	IVecFVec(iOrigin, fOrigin);
	get_user_origin(id, iLook, 3);
	IVecFVec(iLook, fLook);
	    
	fLength = get_distance_f(fLook, fOrigin);
	if (fLength == 0.0) fLength = 1.0;

	vMoveTo[0] = (fOrigin[0] + (fLook[0] - fOrigin[0]) * g_fEntDist[id] / fLength) + g_fOffset[id][0];
	vMoveTo[1] = (fOrigin[1] + (fLook[1] - fOrigin[1]) * g_fEntDist[id] / fLength) + g_fOffset[id][1];
	vMoveTo[2] = (fOrigin[2] + (fLook[2] - fOrigin[2]) * g_fEntDist[id] / fLength) + g_fOffset[id][2];
	vMoveTo[2] = float(floatround(vMoveTo[2], floatround_floor));

	entity_set_origin(g_iOwnedEnt[id], vMoveTo);
	return FMRES_HANDLED;
}
// Zachytenie bloku
public cmdGrabEnt(id)
{
	if (g_iOwnedEnt[id] && is_valid_ent(g_iOwnedEnt[id])) {
		cmdStopEnt(id);
		return PLUGIN_HANDLED;
	}

	if ((IsZombie(id) || !g_CanBuild || !IsAlive(id)) && !IsUserAdmin(id))
		return PLUGIN_HANDLED;

	new ent, bodypart;
	get_user_aiming (id, ent, bodypart);

	if(!g_EntOwner[ent]) { // Rezervacia objektov - ent??
		if(IsUserPremium(id)) {
			if(g_iOwnedEntities[id] <= BLOCK_RESERVE_PREMIUM) {			
				g_EntOwner[ent] = id;
				g_iOwnedEntities[id]++;
			}
		} else {
			if(g_iOwnedEntities[id] <= BLOCK_RESERVE_NORMAL) {			
				g_EntOwner[ent] = id;
				g_iOwnedEntities[id]++;
			}
		}
	} else if (g_EntOwner[ent] != id && !IsUserAdmin(id)) { // Rezervacia objektov
		client_print (id, print_center, "Tento objekt uz ma niekto rezervovany!");
		return PLUGIN_HANDLED;
	}

	if (!is_valid_ent(ent) || ent == g_iEntBarrier || IsAlive(ent) || IsMovingEnt(ent))
		return PLUGIN_HANDLED;

	new szClass[10], szTarget[7];
	entity_get_string(ent, EV_SZ_classname, szClass, 9);
	entity_get_string(ent, EV_SZ_targetname, szTarget, 6);
	if (!equal(szClass, "func_wall") || equal(szTarget, "ignore"))
		return PLUGIN_HANDLED;

	new Float:fOrigin[3], iAiming[3], Float:fAiming[3];
	
	get_user_origin(id, iAiming, 3);
	IVecFVec(iAiming, fAiming);
	entity_get_vector(ent, EV_VEC_origin, fOrigin);

	g_fOffset[id][0] = fOrigin[0] - fAiming[0];
	g_fOffset[id][1] = fOrigin[1] - fAiming[1];
	g_fOffset[id][2] = fOrigin[2] - fAiming[2];
	
	g_fEntDist[id] = get_user_aiming(id, ent, bodypart);

	if (g_fEntDist[id] < 50.0)
		g_fEntDist[id] = 50.0;
	else if (g_fEntDist[id] > 960.0)
		return PLUGIN_HANDLED;

	set_pev(ent, pev_rendermode, kRenderTransColor);
	set_pev(ent, pev_rendercolor, g_Color[g_pColor[id]]);
	set_pev(ent, pev_renderamt, g_RenderColor[g_pColor[id]]);
		
	MovingEnt(ent);
	SetEntMover(ent, id);
	g_iOwnedEnt[id] = ent;

	return PLUGIN_HANDLED;
}
// Pustenie bloku
public cmdStopEnt(id)
{
	if (!g_iOwnedEnt[id])
		return PLUGIN_HANDLED;

	new ent = g_iOwnedEnt[id];
	
	set_pev(ent, pev_rendermode, kRenderNormal);
	
	UnsetEntMover(ent);
	SetLastMover(ent,id);
	g_iOwnedEnt[id] = 0;
	g_LastMover[ent] = id;
	UnmovingEnt(ent);

	return PLUGIN_HANDLED;
}
// Informacie pri zamiereni na blok
public fw_Traceline(Float:start[3], Float:end[3], conditions, id, trace)
{
	if (!IsAlive(id)) return PLUGIN_HANDLED;
	
	new ent = get_tr2(trace, TR_pHit);
	
	if (is_valid_ent(ent))
	{
		new ent, body;
		get_user_aiming(id, ent, body);
		
		new cname[10], tname[7];
		entity_get_string(ent, EV_SZ_classname, cname, 9);
		entity_get_string(ent, EV_SZ_targetname, tname, 6);
		if (equal(cname, "func_wall") && !equal(tname, "ignore") && ent != g_iEntBarrier)
		{
			if ((g_CanBuild || IsUserAdmin(id)) && !IsMovingEnt(ent))
			{
				set_hudmessage(0, 50, 255, -1.0, 0.55, 0, 0.0, 2.0, 0.01, 0.01);

				if (g_EntOwner[ent])
				{
					new entowner[35];
					get_user_name(g_EntOwner[ent],entowner,34);
					ShowSyncHudMsg(id, g_HudChannel_info, "Tento objekt uz ma rezervovany: %s", entowner);
				}
				else
				{
					if(g_LastMover[ent] && IsUserAdmin(id)) {
						new lastmover[35];
						get_user_name(g_LastMover[ent], lastmover, 34);
						ShowSyncHudMsg(id, g_HudChannel_info, "Posledny pohyb: %s", lastmover);
					} else if(!IsUserAdmin(id) && g_CanBuild) ShowSyncHudMsg(id, g_HudChannel_info, "Tlacidlom E mozes pohybovat s tymto objektom!");
				}
			}
		}
	}
	else ClearSyncHud(id, g_HudChannel_info);
	
	return PLUGIN_HANDLED;
}

/* STOCKS - ColorChat */
static ChatColor(const id, const input[], any:...) {
	new count = 1, players[32];
	static msg[191];
	vformat(msg, 190, input, 3);
    
	replace_all(msg, 190, "!g", "^4");
	replace_all(msg, 190, "!t", "^3");
	replace_all(msg, 190, "!y", "^1");
    
	if(id) players[0] = id;
	else get_players(players, count, "ch"); { // broadcast ? all
		for(new i = 0; i < count; i++) {
			if(IsConnected(players[i])) {
				message_begin(MSG_ONE_UNRELIABLE, g_iSayText, _, players[i]);
				write_byte(players[i]);
				write_string(msg);
				message_end();
			}
		}
	}
} 

static ScreenFade(plr, Float:fDuration, red, green, blue, alpha) {
    new i = plr ? plr : get_maxplayers();
    if( !i )
    {
        return 0;
    }
    
    message_begin(plr ? MSG_ONE_UNRELIABLE : MSG_ALL, get_user_msgid( "ScreenFade"), {0, 0, 0}, plr);
    write_short(floatround(4096.0 * fDuration, floatround_round));
    write_short(floatround(4096.0 * fDuration, floatround_round));
    write_short(4096);
    write_byte(red);
    write_byte(green);
    write_byte(blue);
    write_byte(alpha);
    message_end();
    
    return 1;
} 

static ScreenShake(plr, Float:amplitude, Float:duration, Float:frequency) {
	new i = plr ? plr : get_maxplayers();
	if( !i )
	{
		return 0;
	}

	new amp, dura, freq;
	amp = clamp(floatround(amplitude * float(1<<12)), 0, 0xFFFF);
	dura = clamp(floatround(duration * float(1<<12)), 0, 0xFFFF);
	freq = clamp(floatround(frequency * float(1<<8)), 0, 0xFFFF);

	message_begin(plr ? MSG_ONE_UNRELIABLE : MSG_ALL, get_user_msgid("ScreenShake"), _, plr);
	write_short(amp);	// amplitude
	write_short(dura);	// duration
	write_short(freq);	// frequency
	message_end();

	return 1;
}