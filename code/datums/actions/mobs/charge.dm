/datum/action/cooldown/charge
	name = "Charge"
	icon_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
	desc = "Allows you to charge at a chosen position."
	cooldown_time = 15
	text_cooldown = FALSE
	click_to_activate = TRUE
	shared_cooldown = MOB_SHARED_COOLDOWN
	/// Delay before the charge actually occurs
	var/charge_delay = 3
	/// The amount of turfs we move past the target
	var/charge_past = 2
	/// The sleep time before moving in deciseconds while charging
	var/charge_speed = 0.5
	/// The damage the charger does when bumping into something
	var/charge_damage = 30
	/// If we destroy objects while charging
	var/destroy_objects = TRUE
	/// Associative boolean list of chargers that are currently charging
	var/list/charging = list()
	/// Associative direction list of chargers that lets our move signal know how we are supposed to move
	var/list/next_move_allowed = list()

/datum/action/cooldown/charge/New(Target, delay, past, speed, damage, destroy)
	. = ..()
	if(delay)
		charge_delay = delay
	if(past)
		charge_past = past
	if(speed)
		charge_speed = speed
	if(damage)
		charge_damage = damage
	if(destroy)
		destroy_objects = destroy

/datum/action/cooldown/charge/Activate(atom/target_atom)
	// start pre-cooldown so that the ability can't come up while the charge is happening
	StartCooldown(100)
	do_charge(owner, target_atom, charge_delay, charge_past)
	StartCooldown()

/datum/action/cooldown/charge/proc/do_charge(atom/movable/charger, atom/target_atom, delay, past)
	if(!target_atom || target_atom == owner)
		return
	var/chargeturf = get_turf(target_atom)
	if(!chargeturf)
		return
	charger.setDir(get_dir(charger, target_atom))
	var/turf/T = get_ranged_target_turf(chargeturf, charger.dir, past)
	if(!T)
		return
	new /obj/effect/temp_visual/dragon_swoop/bubblegum(T)
	RegisterSignal(charger, COMSIG_MOVABLE_BUMP, .proc/on_bump)
	RegisterSignal(charger, COMSIG_MOVABLE_PRE_MOVE, .proc/on_move)
	RegisterSignal(charger, COMSIG_MOVABLE_MOVED, .proc/on_moved)
	charging[charger] = TRUE
	DestroySurroundings(charger)
	charger.setDir(get_dir(charger, target_atom))
	var/obj/effect/temp_visual/decoy/D = new /obj/effect/temp_visual/decoy(charger.loc, charger)
	animate(D, alpha = 0, color = "#FF0000", transform = matrix()*2, time = 3)
	SLEEP_CHECK_DEATH(delay, charger)
	var/distance = get_dist(charger, T)
	for(var/i in 1 to distance)
		SLEEP_CHECK_DEATH(charge_speed, charger)
		next_move_allowed[charger] = get_dir(charger, T)
		step_towards(charger, T)
		next_move_allowed.Remove(charger)
	UnregisterSignal(charger, COMSIG_MOVABLE_BUMP)
	UnregisterSignal(charger, COMSIG_MOVABLE_PRE_MOVE)
	UnregisterSignal(charger, COMSIG_MOVABLE_MOVED)
	charging.Remove(charger)
	SEND_SIGNAL(owner, COMSIG_FINISHED_CHARGE)
	return TRUE

/datum/action/cooldown/charge/proc/on_move(atom/source, atom/new_loc)
	var/expected_dir = next_move_allowed[source]
	if(!expected_dir)
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE
	var/real_dir = get_dir(source, new_loc)
	if(!(expected_dir & real_dir))
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE
	next_move_allowed[source] = expected_dir & ~real_dir
	if(charging[source])
		new /obj/effect/temp_visual/decoy/fading(source.loc, source)
		DestroySurroundings(source)

/datum/action/cooldown/charge/proc/on_moved(atom/source)
	if(charging[source])
		DestroySurroundings(source)

/datum/action/cooldown/charge/proc/DestroySurroundings(atom/movable/charger)
	if(!destroy_objects)
		return
	for(var/dir in GLOB.cardinals)
		var/turf/T = get_step(charger, dir)
		if(QDELETED(T))
			continue
		if(T.Adjacent(charger))
			if(iswallturf(T) || ismineralturf(T))
				T.attack_animal(charger)
				continue
		for(var/obj/O in T.contents)
			if(!O.Adjacent(charger))
				continue
			if((ismachinery(O) || isstructure(O)) && O.density && !O.IsObscured())
				O.attack_animal(charger)
				break

/datum/action/cooldown/charge/proc/on_bump(atom/movable/source, atom/A)
	if(charging[source])
		if(isturf(A) || isobj(A) && A.density)
			if(isobj(A))
				SSexplosions.med_mov_atom += A
			else
				SSexplosions.medturf += A
		DestroySurroundings()
		hit_target(source, A, charge_damage)

/datum/action/cooldown/charge/proc/hit_target(atom/movable/source, atom/A, damage_dealt)
	if(!isliving(A))
		return
	var/mob/living/L = A
	L.visible_message("<span class='danger'>[source] slams into [L]!</span>", "<span class='userdanger'>[source] tramples you into the ground!</span>")
	source.forceMove(get_turf(L))
	L.apply_damage(damage_dealt, BRUTE, wound_bonus = CANT_WOUND)
	playsound(get_turf(L), 'sound/effects/meteorimpact.ogg', 100, TRUE)
	shake_camera(L, 4, 3)
	shake_camera(source, 2, 3)

/datum/action/cooldown/charge/triple_charge
	name = "Triple Charge"
	desc = "Allows you to charge three times at a chosen position."
	charge_delay = 6

/datum/action/cooldown/charge/triple_charge/Activate(var/atom/target_atom)
	StartCooldown(100)
	for(var/i in 0 to 2)
		do_charge(owner, target_atom, charge_delay - 2 * i, charge_past)
	StartCooldown()

/datum/action/cooldown/charge/hallucination_charge
	name = "Hallucination Charge"
	icon_icon = 'icons/effects/bubblegum.dmi'
	button_icon_state = "smack ya one"
	desc = "Allows you to create hallucinations that charge around your target."
	cooldown_time = 20
	charge_delay = 6
	/// The damage the hallucinations in our charge do
	var/hallucination_damage = 15
	/// Check to see if we are enraged, enraged ability does more
	var/enraged = FALSE

/datum/action/cooldown/charge/hallucination_charge/Activate(var/atom/target_atom)
	StartCooldown(100)
	if(!enraged)
		hallucination_charge(target_atom, 6, 8, 0, 6, TRUE)
		StartCooldown(cooldown_time * 0.5)
		return
	for(var/i in 0 to 2)
		hallucination_charge(target_atom, 4, 9 - 2 * i, 0, 4, TRUE)
	for(var/i in 0 to 2)
		do_charge(owner, target_atom, charge_delay - 2 * i, charge_past)
	StartCooldown()

/datum/action/cooldown/charge/hallucination_charge/do_charge(atom/movable/charger, atom/target_atom, delay, past)
	. = ..()
	if(charger != owner)
		qdel(charger)

/datum/action/cooldown/charge/hallucination_charge/proc/hallucination_charge(atom/target_atom, clone_amount, delay, past, radius, use_self)
	var/starting_angle = rand(1, 360)
	if(!radius)
		return
	var/angle_difference = 360 / clone_amount
	var/self_placed = FALSE
	for(var/i = 1 to clone_amount)
		var/angle = (starting_angle + angle_difference * i)
		var/turf/place = locate(target_atom.x + cos(angle) * radius, target_atom.y + sin(angle) * radius, target_atom.z)
		if(!place)
			continue
		if(use_self && !self_placed)
			owner.forceMove(place)
			self_placed = TRUE
			continue
		var/mob/living/simple_animal/hostile/megafauna/bubblegum/hallucination/B = new /mob/living/simple_animal/hostile/megafauna/bubblegum/hallucination(place)
		INVOKE_ASYNC(src, .proc/do_charge, B, target_atom, delay, past)
	if(use_self)
		do_charge(owner, target_atom, delay, past)

/datum/action/cooldown/charge/hallucination_charge/hit_target(atom/movable/source, atom/A, damage_dealt)
	var/applied_damage = charge_damage
	if(source != owner)
		applied_damage = hallucination_damage
	. = ..(source, A, applied_damage)

/datum/action/cooldown/charge/hallucination_charge/hallucination_surround
	name = "Surround Target"
	icon_icon = 'icons/turf/walls/wall.dmi'
	button_icon_state = "wall-0"
	desc = "Allows you to create hallucinations that charge around your target."
	charge_delay = 6
	charge_past = 2

/datum/action/cooldown/charge/hallucination_charge/hallucination_surround/Activate(var/atom/target_atom)
	StartCooldown(100)
	for(var/i in 0 to 4)
		hallucination_charge(target_atom, 2, 8, 2, 2, FALSE)
		do_charge(owner, target_atom, charge_delay, charge_past)
	StartCooldown()
