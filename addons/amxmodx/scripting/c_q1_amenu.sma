#include <amxmodx>
#include <amxmisc>
#include <bbq6>

#define OPEN_MENU          ADMIN_IMMUNITY

new MenuChosen[33], PlayerChosen[33];

public plugin_init() {
	register_plugin("BaseBuilder Adminmenu", "0.1", "ReeG"); 

	register_concmd("bb_amenu", "bbAmenu", OPEN_MENU, "Admin menu, pre pridavanie bodov, levelov, ..");
    
	register_clcmd("Suma", "handle_value");
}

public bbAmenu(id) {
	if(!(get_user_flags(id) & OPEN_MENU)) return PLUGIN_HANDLED;

	new menu = menu_create("Admin menu^n\w[Q1 by ReeG] \d", "bbAmenu_handle");

	menu_additem(menu, "Pridat body");
	menu_additem(menu, "Pridat XP");
	menu_additem(menu, "Vybrat item");

	// co vam chyba si uz musite pridat

	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}
public bbAmenu_handle(id, menu, item) {
    	if(item == MENU_EXIT) {
        	menu_destroy(menu);
        	return PLUGIN_HANDLED;
    	}
    	switch(item) {
        	case 0: MenuChosen[id] = 1;
        	case 1: MenuChosen[id] = 2;
        	case 2: MenuChosen[id] = 3;
    	}

        PlayersMenu(id);
    	return PLUGIN_HANDLED;
}

public PlayersMenu(id) {
	PlayerChosen[id] = 0;

	new szMenuTitle[128];

	switch(MenuChosen[id]) {
		case 1: formatex(szMenuTitle, charsmax(szMenuTitle), "\rPridat body^n\yVyber hraca \d");
		case 2: formatex(szMenuTitle, charsmax(szMenuTitle), "\rPridat XP \w(%d)^n\yVyber hraca \d", fm_max_user_level());
 		case 3: formatex(szMenuTitle, charsmax(szMenuTitle), "\rVybrat item \w(0-2)^n\yVyber hraca \d");
	}

	new menu = menu_create(szMenuTitle, "PlayersMenu_handle");

	new players[32], pnum, tempid;
	new szName[32], szUserId[10];
	get_players(players, pnum);

	for(new i; i < pnum; i++)
	{
		tempid = players[i];

		get_user_name(tempid, szName, charsmax(szName));
		// zobrazovanie bodov pri hracoch?
		formatex(szUserId, charsmax(szUserId), "%d", get_user_userid(tempid));

		menu_additem(menu, szName, szUserId, 0);
	}

	menu_setprop(menu, MPROP_BACKNAME, "Zpet");
	menu_setprop(menu, MPROP_NEXTNAME, "Dalsie");
	menu_setprop(menu, MPROP_EXITNAME, "Zavriet");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public PlayersMenu_handle(id, menu, item) {
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
        	PlayerChosen[id] = player;
        	client_cmd(id, "messagemode Suma");
    	}
    	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public handle_value(id) {
	new szSay[32];
	read_args(szSay, charsmax(szSay));
	remove_quotes(szSay);
	
	if(!is_str_num(szSay) || equal(szSay, " ") || !PlayerChosen[id])
	{
		PlayersMenu(id);
		return PLUGIN_HANDLED;
	}
	call_native(id, szSay);
	return PLUGIN_HANDLED;
}

public call_native(id, args[]) {
	new parseNum = str_to_num(args);
	switch(MenuChosen[id]) {
        	case 1: if(parseNum <= 10000000) fm_set_user_body(PlayerChosen[id], parseNum);
        	case 2: if(parseNum <= 25000) fm_set_user_xp(PlayerChosen[id], parseNum);
        	case 3: if(parseNum < 3 && parseNum >= 0) fm_set_user_item(PlayerChosen[id], parseNum);
	}
	return PLUGIN_HANDLED;
}