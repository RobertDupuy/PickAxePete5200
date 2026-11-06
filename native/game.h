#ifndef PETE_GAME_H
#define PETE_GAME_H
/* Game rules only. No addresses, device registers, emulated CPU, or video API. */
typedef unsigned char byte;
typedef signed char delta;
enum { SELECT_MINE, PLAYING, DYING, ENTERING_MINE };
enum { NO_ITEM, PICK, KEY };
enum { WALL=1, FLOOR=2, PLATFORM_EDGE=16, GAP=128 };
enum {
 FALL_0, FALL_1, FALL_2, FALL_3,
 JUMP_L, DUCK_L, JUMP_R, DUCK_R,
 STAND_L, STAND_R, STAND_F,
 LOW_L, LOW_R, LOW_F,
 CROUCH_L, FLAT_L, CROUCH_R, FLAT_R,
 WALK_L0, WALK_L1, WALK_L2, WALK_L3,
 WALK_R0, WALK_R1, WALK_R2, WALK_R3,
 HANG, CLIMB_L, CLIMB_R, CLIMB_IDLE, CLIMB_0, CLIMB_1,
 DEATH_0, DEATH_1, DEATH_2, DEATH_3, DEATH_4
};
extern byte mode, frame, mine_number, mine_color, scene_changed;
extern byte floors[9], score[4], high_score[4], name_chars[6], name_cursor;
extern byte score_pending, difficulty, score_changed, name_changed;
extern byte pete_x, pete_y, pete_shape, pick_life, has_key;
extern byte jump_phase, walk_phase, walk_clock, terrain, evade_cooldown;
extern delta last_x, last_y;
extern byte ladder_x, ladder_y, ladder_shape, ladder_level, ladder_stage;
extern byte ladder_phase, ladder_hold, on_ladder;
extern byte item_x, item_y, item_kind, item_shape, item_age;
extern byte effect_x, effect_y, effect_phase, effect_clock;
extern byte rock_x[5], rock_y[5], rock_x_energy[5], rock_y_energy[5];
extern byte rock_fall[5], rock_decay[5], rock_cursor, door_cursor;
extern byte door_color[3], door_clock[3], door_open[3];
extern const byte door_y[3];
enum { SND_NONE=0, SND_EVADE=0x56, SND_BOUNCE=0x64, SND_CRASH=0x6a,
 SND_FALL=0x74, SND_HIT=0x78, SND_ITEM=0x7f, SND_DEATH=0x87,
 SND_FADE=0x91, SND_SPAWN=0x97, SND_KEY=0x9f,
 SND_JUMP=0xa5, SND_DUCK=0xab, SND_MINE=0xb1 };
extern byte death_clock, transition_clock, sound_event, sound_queue;
extern byte effect_shape, effect_color, effect_size, glint_cursor;
extern byte item_mask[8], transition_stage;
/* Entropy is supplied by an independent clock; rules do not read device state. */
extern byte entropy_value, entropy_fraction;
void entropy_frame(void);
void entropy_advance(byte cycles);
void entropy_write(byte value);
extern delta input_x, input_y;
extern byte input_fire, input_mine, input_name;
extern byte pete_hits_rock, pete_hits_item, pete_hits_ladder;
/* Terrain query: position and requested movement in; flags/corrections out. */
extern byte query_x, query_y, contact_flags;
extern delta move_x, move_y, correction_x, correction_y;
void terrain_query(void);
void game_init(void);
void game_tick(void);
void new_round(void);
byte random_byte(void);
#endif
