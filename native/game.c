#include "game.h"
#include "assets.h"

/* The hot scalar game state is real 6502 zero-page RAM, not simulated registers. */
#ifdef __CC65__
#pragma bss-name(push, "ZEROPAGE")
#endif
byte mode, frame, pete_x, pete_y, pete_shape, pick_life, has_key;
byte jump_phase, walk_phase, walk_clock, terrain, evade_cooldown;
delta last_x, last_y;
byte query_x, query_y, contact_flags;
delta move_x, move_y, correction_x, correction_y;
delta input_x, input_y;
byte input_fire, pete_hits_rock, pete_hits_item, pete_hits_ladder;
/* Non-recursive routines deliberately share scratch, but interrupts never use it. */
static byte i,j,n,t,u,mask;
#ifndef __CC65__
static byte col,level,gap,distance,edge_zone,target_x,target_y;
#endif
byte rock, hit;
#ifdef __CC65__
#pragma bss-name(pop)
#pragma zpsym("mode")
#pragma zpsym("frame")
#pragma zpsym("pete_x")
#pragma zpsym("pete_y")
#pragma zpsym("pete_shape")
#pragma zpsym("pick_life")
#pragma zpsym("has_key")
#pragma zpsym("jump_phase")
#pragma zpsym("walk_phase")
#pragma zpsym("walk_clock")
#pragma zpsym("terrain")
#pragma zpsym("evade_cooldown")
#pragma zpsym("last_x")
#pragma zpsym("last_y")
#pragma zpsym("query_x")
#pragma zpsym("query_y")
#pragma zpsym("contact_flags")
#pragma zpsym("move_x")
#pragma zpsym("move_y")
#pragma zpsym("correction_x")
#pragma zpsym("correction_y")
#pragma zpsym("input_x")
#pragma zpsym("input_y")
#pragma zpsym("input_fire")
#pragma zpsym("pete_hits_rock")
#pragma zpsym("pete_hits_item")
#pragma zpsym("pete_hits_ladder")
#endif

byte mine_number, mine_color, scene_changed;
byte floors[9], score[4], high_score[4], name_chars[6], name_cursor;
byte score_pending, difficulty, score_changed, name_changed;
byte ladder_x, ladder_y, ladder_shape, ladder_level, ladder_stage;
byte ladder_phase, ladder_hold, on_ladder;
byte item_x, item_y, item_kind, item_shape, item_age;
byte effect_x, effect_y, effect_phase, effect_clock;
byte effect_shape, effect_color, effect_size, glint_cursor, item_mask[8], transition_stage;
byte rock_x[5], rock_y[5], rock_x_energy[5], rock_y_energy[5];
byte rock_fall[5], rock_decay[5], rock_cursor, door_cursor;
byte door_color[3], door_clock[3], door_open[3];
const byte door_y[3]={178,106,34};
byte death_clock, transition_clock, sound_event, sound_queue, input_mine, input_name;
static const byte floor_masks[8]={1,2,4,8,16,32,64,128};
static const byte ladder_heights[6]={171,147,123,99,75,51};
static const byte ladder_masks[6]={64,32,16,8,4,2};
static const byte height_threshold[6]={171,147,123,99,69,51};

#define NEAR(a,b,d) ((byte)((byte)(a)-(byte)(b)+((d)-1)) < (byte)(2*(d)-1))

/* Collision geometry, derived from cartridge bank 0 $900-$9cc.
   Positions are logical game units. Platforms have 16-unit segments and
   24-unit vertical spacing. A query never reads a display or a hardware latch. */
#ifndef __CC65__
void terrain_query(void)
{
 target_x=query_x+move_x; target_y=query_y+move_y;
 contact_flags=0; correction_x=0; correction_y=0; col=0;
 if(target_x<=8) { contact_flags=WALL; gap=8-target_x; }
 else if(target_x>=146) { contact_flags=WALL; col=8; gap=146-target_x; }
 else {
  gap=17;
  while(gap<target_x) { gap+=16; ++col; }
  gap-=target_x;
 }
 correction_x=(delta)gap;
 level=1; distance=39;
 while(distance<target_y && level<8) { distance+=24; ++level; }
 if(level==8) { contact_flags|=FLOOR; return; }
 distance-=target_y; edge_zone=0;
 if(move_y>=0 && distance<3) correction_y=(delta)(distance-3);
 else {
  --level;
  if(distance<15) return;
  distance-=15;
  edge_zone=(distance!=0);
  correction_y=(delta)distance;
  if(move_y>=0 || distance==0) correction_y=-correction_y;
 }
 if(move_y) correction_y+=move_y; else correction_y=0;
 contact_flags|=FLOOR;
 mask=floor_masks[level];
 if(!(floors[col]&mask)) {
  if(gap<10 || !col || !(floors[col-1]&mask)) {
   contact_flags|=GAP; return;
  }
 }
 if(gap>=10 && edge_zone) {
  correction_x=(delta)(gap-16);
  if(move_x<0) correction_x=-correction_x;
  correction_x+=move_x; contact_flags|=PLATFORM_EDGE;
 }
}

#endif

static void apply_terrain(void)
{
 if(contact_flags&(WALL|PLATFORM_EDGE)) move_x=correction_x;
 if(!(contact_flags&GAP) && (contact_flags&FLOOR)) move_y=correction_y;
}

void clear_objects(void)
{
 for(i=0;i<5;++i) {
  rock_x[i]=rock_y[i]=248; rock_fall[i]=rock_decay[i]=0;
  rock_x_energy[i]=rock_y_energy[i]=0;
 }
 effect_phase=effect_clock=effect_size=glint_cursor=0; effect_x=effect_y=248;
 for(i=0;i<8;++i) item_mask[i]=255; transition_stage=0;
 item_kind=NO_ITEM; item_x=item_y=248; item_age=0;
 jump_phase=walk_phase=walk_clock=0; last_x=last_y=0;
 ladder_level=ladder_stage=ladder_phase=ladder_hold=on_ladder=0;
 ladder_x=ladder_y=248; ladder_shape=0;
 death_clock=transition_clock=0; pick_life=0; has_key=0; evade_cooldown=0;
 rock_cursor=3;
}

void new_round(void)
{
 clear_objects();
 pete_x=76; pete_y=128; pete_shape=STAND_F; terrain=0;
 ladder_x=105; ladder_y=171;
 pick_life=1; frame=0;
 item_x=80; item_y=129; item_shape=0;
 for(i=0;i<3;++i) { door_color[i]=(byte)(4>>i); door_open[i]=door_clock[i]=0; }
 mode=PLAYING; scene_changed=1;
}

static void save_high_score(void)
{
 for(i=0;i<4;++i) {
  if(score[i]<high_score[i]) return;
  if(score[i]>high_score[i]) break;
 }
 /* Original ROM $5c3: an equal or higher completed score asks for a name. */
 for(i=0;i<4;++i) high_score[i]=score[i];
#ifdef PICKAXE_5200
 /* The 5200 is a single-player console: retain a fixed player label. */
 name_chars[0]=15; name_chars[1]=14; name_chars[2]=44;
 name_chars[3]=19; name_chars[4]=1; name_chars[5]=12; /* PLYR1 + space */
 name_cursor=255; name_changed=1;
#else
 for(i=0;i<6;++i) name_chars[i]=13;
 name_cursor=0; name_changed=1;
#endif
}

static void start_game(void)
{
 save_high_score();
 for(i=0;i<4;++i) score[i]=0;
 score_pending=0; score_changed=1; difficulty=0; mine_color=4;
 for(i=0;i<9;++i) floors[i]=mine_layouts[mine_number*9+i];
 new_round();
}

void game_init(void)
{
 input_mine=input_name=255; mine_number=0;
 for(i=0;i<4;++i) score[i]=high_score[i]=0;
#ifdef PICKAXE_5200
 /* The 5200 is a single-player console: retain a fixed player label. */
 name_chars[0]=15; name_chars[1]=14; name_chars[2]=44;
 name_chars[3]=19; name_chars[4]=1; name_chars[5]=12; /* PLYR1 + space */
 name_cursor=255; name_changed=1;
#else
 for(i=0;i<6;++i) name_chars[i]=13;
 name_cursor=0; name_changed=1;
#endif
 start_game(); mode=SELECT_MINE;
}

static void score_tick(void)
{
 if(!score_pending) return;
 --score_pending; score_changed=1;
 if(!(random_byte()&1) && difficulty<255) ++difficulty;
 i=3;
 while(++score[i]==10) { score[i]=0; if(!i) break; --i; }
}

static void pete_ground_step(void)
{
 query_x=pete_x; query_y=pete_y+2; move_y=1;
 terrain_query(); apply_terrain();
 pete_x+=move_x; pete_y+=move_y;
 if(!jump_phase) {
  terrain=contact_flags;
  if((terrain&GAP) || !(terrain&FLOOR)) {
   pete_shape=FALL_0+((frame>>2)&3); return;
  }
 }
 if(++walk_clock!=3) return;
 walk_clock=0;
 if(move_x) {
  if(++walk_phase==5) walk_phase=1;
  pete_shape=(move_x<0?WALK_L0:WALK_R0)+walk_phase-1;
 } else {
  pete_shape=(last_y>0?LOW_L:STAND_L);
  if(last_x>0) ++pete_shape;
  else if(!last_x) pete_shape+=2;
 }
}

static void pete_step(void)
{
 move_x=input_x; move_y=input_y;
 if(!jump_phase) {
  if(move_x || move_y) last_x=move_x;
  if(move_y) last_y=move_y;
  if((terrain&GAP) || !(terrain&FLOOR)) {
   move_x=0; last_x=0; pete_ground_step(); return;
  }
  if(!input_fire) { pete_ground_step(); return; }
 }
 jump_phase=(jump_phase+1)&31;
 if(!jump_phase) {
  move_x=input_x;
  if(input_x || input_y) last_x=input_x;
  if(input_y) last_y=input_y;
  if((terrain&GAP) || !(terrain&FLOOR)) { move_x=0; last_x=0; }
  pete_ground_step(); return;
 }
 move_x=last_x; move_y=last_y;
 if(!move_y) move_y=-1;
 t=(move_y<0?JUMP_L:CROUCH_L)+(move_x<0?2:0);
 if(move_y>=0) { move_y=0; if(!(jump_phase&1)) move_x=0; }
 if((jump_phase&24)==24) { last_y=0; pete_ground_step(); return; }
 pete_shape=t;
 if(jump_phase&16) {
  move_y=0; ++pete_shape;
 } else if(jump_phase&8) { move_y=0; ++pete_shape; }
 if(jump_phase==1) sound_event=(move_y<0?SND_JUMP:SND_DUCK);
 pete_x+=move_x; pete_y+=move_y;
 if(pete_x<10) { pete_x=10; jump_phase=0; terrain=GAP; }
 if(pete_x>=144) { pete_x=144; jump_phase=0; terrain=GAP; }
}

static void ladder_step(void)
{
 if((input_y<0 || pete_hits_ladder || pete_hits_item) &&
    NEAR(pete_y,ladder_y,9) && NEAR(pete_x,ladder_x,9)) {
  ladder_phase=1; on_ladder=1;
 }
 if(ladder_phase&1) {
  if(ladder_stage<15) ++ladder_stage;
  else {
   t=pete_y-ladder_y;
   if(t<12 && !ladder_hold) ladder_hold=16;
   if(ladder_hold) --ladder_hold;
   if(!ladder_hold) ++ladder_phase;
  }
 } else if(ladder_stage) --ladder_stage;
 else {
  ++ladder_phase;
  if(pick_life || has_key) {
   ladder_level=0;
   while(ladder_level<5 && pete_y<height_threshold[ladder_level]) ++ladder_level;
  }
  t=ladder_level; if(++ladder_level>=7) ladder_level=1;
  if(t>=6) t=0;
  ladder_y=ladder_heights[t]; mask=ladder_masks[t];
  j=random_byte()&7; entropy_advance(7); u=random_byte()&64;
  for(n=0;n<9;++n) {
   if(floors[j]&mask) break;
   if(u) { if(!j) j=9; --j; } else if(++j==9) j=0;
  }
  ladder_x=(n==9?248:13+(j<<4));
 }
 ladder_shape=ladder_stage>>2;
}

static void climb_step(void)
{
 if(!on_ladder) return;
 on_ladder=0; jump_phase=walk_clock=walk_phase=0;
 if(input_x) last_x=input_x;
 last_y=0;
 if(input_x) pete_x+=input_x; else pete_x=ladder_x-1;
 pete_y+=input_y;
 pete_shape=HANG;
 if((byte)(pete_y+6)>=ladder_y) {
  pete_shape=CLIMB_IDLE;
  if(input_y) { pete_shape=(frame&4?CLIMB_0:CLIMB_1); if(!(frame&4)) ++pete_x; }
  if(input_x) pete_shape=(input_x<0?CLIMB_L:CLIMB_R);
 }
}

void effect_start(void)
{
 effect_x=query_x; effect_y=query_y; effect_phase=1; effect_clock=0;
}

static void effect_step(void)
{
 if(!effect_phase) {
  if(glint_cursor>=5) glint_cursor=0;
  i=glint_cursor++;
  if(rock_fall[i] && rock_y[i]!=248) {
   effect_x=rock_x[i]; effect_y=rock_y[i]; effect_color=1; effect_size=0;
   effect_shape=(frame&8)?0:1;
  } else effect_x=effect_y=248;
  return;
 }
 effect_shape=effect_phase-1;
 if(!effect_clock) sound_event=SND_CRASH;
 ++effect_clock;
 effect_size=(effect_clock>=9);
 effect_color=(effect_clock==9?0:3);
 if(effect_clock==5) ++effect_phase;
 if(effect_clock==9) { effect_x-=5; effect_y-=10; }
 if(effect_clock==16) { effect_phase=effect_clock=0; effect_x=effect_y=248; }
}

static void spawn_item(void)
{
 if(item_kind || pick_life || effect_clock!=8) return;
 t=random_byte(); item_kind=PICK;
 if((t&3) && !has_key) {
  entropy_advance(15);
  if(!(random_byte()&8) && effect_y<128) { item_kind=NO_ITEM; return; }
  item_kind=KEY;
 }
 item_x=effect_x; item_y=effect_y; item_age=0;
}

#ifndef __CC65__
static void item_step(void)
{
 for(i=0;i<8;++i) item_mask[i]=255;
 if(pick_life) {
  if(pick_life>=193) {
   sound_queue=0x82;
   if(!(frame&2)) {
    t=random_byte();
    for(i=1;i<6;++i) { item_mask[i]=t; t=~t; t=(t>>1)|(t<<7); }
   }
  }
  return;
 }
 if(!item_kind) return;
 item_y+=(item_kind==KEY?-2:2);
 if(item_y<28 || item_y>=176) {
  item_y=(item_y<28?28:176); item_age+=2;
  if(!item_age) { item_kind=NO_ITEM; item_x=item_y=248; return; }
  item_shape=(item_kind==KEY?4:0);
  if(item_age>=128) {
   sound_queue=0x82; t=random_byte();
   for(i=0;i<8;++i) { t=~t; t=(t>>1)|(t<<7); item_mask[i]=t; }
  }
 } else {
  sound_queue=0x84;
  item_shape=((frame>>2)&3)+(item_kind==KEY?4:0);
 }
}

#else
void item_step(void);
#endif

/* Bank 0 $a99-$af1. Keep the pick's actual position/artwork as object state,
   shared by drawing and collision tests. Stationary vertical input forces
   the low stroke without requiring the fire button. */
static void held_pick_step(void)
{
 item_x=pete_x+(last_x<0?-4:4);
 item_y=pete_y+1; item_shape=0;
 if(!(frame&4)) { item_y-=8; item_shape=1; }
 if(terrain&GAP) { item_y=pete_y+1; item_shape=0; }
 else if(jump_phase) item_y+=last_y>0?8:-1;
 else if(!input_fire && !input_x) {
  last_y=(frame&4)?1:-1;
  if(input_y) {
   last_y=input_y; item_y=pete_y+1; item_shape=0;
  }
 }
 if(last_x<0) item_shape+=2;
}

static void pick_step(void)
{
 if(pick_life) {
  if(!(frame&4) && !(terrain&GAP)) sound_queue=0x88;
  if(!(frame&2) && ++pick_life==0) { item_x=item_y=248; return; }
  held_pick_step();
  return;
 }
 if(item_kind && pete_hits_item && NEAR(pete_y,item_y,11) &&
    NEAR(pete_x,item_x,7)) {
  if(item_kind==PICK) { pick_life=1; score_pending+=5; }
  else { has_key=1; score_pending+=10; sound_event=SND_KEY; }
  item_kind=NO_ITEM; item_x=item_y=248;
 }
 spawn_item();
}

static void spawn_rock(void)
{
 if(frame&31) return;
 entropy_advance(7);
 if(random_byte()&1) return;
 for(rock=0;rock<5;++rock) if(rock_y[rock]==248) break;
 if(rock==5) return;
 mask=(difficulty|1); if(mask<20) mask=15;
 entropy_advance((difficulty<20?27:25)+15*rock);
 t=random_byte(); t=(t<<1)|(t>>7); entropy_advance(1); entropy_write(t); entropy_advance(1);
 rock_x_energy[rock]=t&mask;
 entropy_advance((t&1)?19:15); rock_y_energy[rock]=(~random_byte())&mask;
 rock_decay[rock]=rock_fall[rock]=0;
 move_x=8+(rock_x_energy[rock]&3);
 if(rock_x_energy[rock]&1) move_x=-move_x;
 entropy_advance(15);
 if(difficulty>=20) { t=random_byte(); door_cursor=t>>6; entropy_advance(5); }
 entropy_advance(6+(door_cursor==3?2:0));
 if(++door_cursor>=4) door_cursor=1;
 if(!(random_byte()&16) && pete_y<85) door_cursor=3;
 t=door_cursor-1;
 door_open[t]=1; door_clock[t]=192;
 rock_x[rock]=77+move_x; rock_y[rock]=door_y[t]; sound_queue=8;
}

#ifndef __CC65__
static delta velocity(byte energy)
{
 byte speed;
 speed=(energy&128)?3:((energy&64)?2:1);
 return (energy&1)?-(delta)speed:(delta)speed;
}

#endif

#ifndef __CC65__
void rock_objects(void)
{
 hit=0;
 for(j=0;j<5;++j) {
  if(j==rock || rock_y[j]==248) continue;
  if(NEAR(query_x+move_x,rock_x[j],8) &&
     NEAR(query_y+move_y,rock_y[j],12)) {
   rock_fall[j]=1; effect_start(); hit=1; break;
  }
 }
 if(!hit) for(j=0;j<3;++j) {
  if(NEAR(query_x+move_x,77,8) &&
     NEAR(query_y+move_y,door_y[j],12)) {
   door_open[j]=1; door_clock[j]=192; hit=1; break;
  }
 }
 if(hit) { rock_x[rock]=rock_y[rock]=248; move_x=move_y=0; contact_flags=0; }
}

#else
void rock_objects(void);
#endif

#ifndef __CC65__
void rock_step(void)
{
 if(++rock_cursor==5) rock_cursor=0;
 rock=rock_cursor;
 if(rock_y[rock]==248) return;
 query_x=rock_x[rock]; query_y=rock_y[rock];
 if(rock_fall[rock]) {
  sound_queue=4;
  move_x=0; move_y=2; rock_objects();
  if(hit) return;
  rock_y[rock]+=2;
  if(rock_y[rock]>=182) { query_y=rock_y[rock]; effect_start(); rock_x[rock]=rock_y[rock]=248; }
  return;
 }
 move_x=velocity(rock_x_energy[rock]); move_y=velocity(rock_y_energy[rock]);
 terrain_query(); apply_terrain(); rock_objects();
 if(hit) return;
 rock_x[rock]+=move_x; rock_y[rock]+=move_y;
 if(contact_flags&(WALL|PLATFORM_EDGE)) {
  if(rock_x_energy[rock]&254) rock_x_energy[rock]-=2;
  rock_x_energy[rock]^=1; ++sound_queue;
 }
 if((contact_flags&GAP) && rock_y_energy[rock]<254) rock_y_energy[rock]+=2;
 if(!(contact_flags&(GAP|PLATFORM_EDGE)) && (contact_flags&FLOOR)) {
  if(rock_y_energy[rock]&254) { rock_y_energy[rock]=(rock_y_energy[rock]-2)^1; ++sound_queue; }
  else rock_y_energy[rock]=0;
 }
 if((rock_y_energy[rock]&1) && !(rock_y_energy[rock]&224)) {
  rock_decay[rock]+=2;
  if(rock_decay[rock]>=rock_y_energy[rock]) {
   rock_decay[rock]=0; rock_y_energy[rock]&=254;
   if(rock_y_energy[rock]) rock_y_energy[rock]-=2;
   if(rock_x_energy[rock]&254) rock_x_energy[rock]-=2;
  }
 }
}

#else
void rock_step(void);
#endif

#ifndef __CC65__
static void pick_rocks(void)
{
 if(!pick_life) return;
 query_x=item_x; query_y=item_y;
 for(i=0;i<5;++i) {
  if(rock_y[i]==248) continue;
  if(NEAR(query_y,rock_y[i],12) && NEAR(query_x,rock_x[i],8)) {
   score_pending+=3; effect_start(); rock_x[i]=rock_y[i]=248; break;
  }
 }
}

#else
void pick_rocks(void);
#endif

#ifndef __CC65__
static void pete_contacts(void)
{
 if(evade_cooldown) --evade_cooldown;
 if(mode==DYING) return;
 for(i=0;i<5;++i) {
  if(rock_y[i]==248) continue;
  t=pete_y>rock_y[i]?pete_y-rock_y[i]:rock_y[i]-pete_y;
  if(t>=10 || !NEAR(pete_x,rock_x[i],3)) continue;
  if(pete_hits_rock && !(jump_phase && t>=6)) {
   mode=DYING; death_clock=1; return;
  }
  if(jump_phase && !evade_cooldown) { evade_cooldown=9; ++score_pending; sound_event=SND_EVADE; }
  return;
 }
 for(i=0;i<3;++i) {
  if(!NEAR(pete_x,77,7) || !NEAR(pete_y,door_y[i],6)) continue;
  if(has_key) {
   /* Door RGB -> mine grid palette order. */
   t=door_color[i]; mine_color=((t&1)?4:0)|((t&2)?2:0)|((t&4)?1:0);
   score_pending+=20; clear_objects(); mode=ENTERING_MINE;
   transition_clock=1; pete_x=72; pete_y=104; sound_queue=0xa0;
  } else {
   door_open[i]=1; door_clock[i]=192;
   last_x=(random_byte()&1)?1:-1; last_y=-1; ++jump_phase; sound_event=(last_x>0?SND_JUMP:SND_DUCK);
  }
  return;
 }
}

#else
void pete_contacts(void);
#endif

static void remove_floor(void)
{
 j=(random_byte()&7)+1;
 for(n=0;n<8;++n) {
  if(j==4) ++j;
  if(j==9) j=0;
  /* The ROM samples even for empty columns and scans from bit 7-T down. */
  t=7-(random_byte()&7);
  mask=floors[j]&126;
  if(mask) {
   for(u=0;u<8;++u) {
    if(mask&floor_masks[t]) { floors[j]=(mask&~floor_masks[t])|129; return; }
    t=(t-1)&7;
   }
  }
  ++j;
 }
}

void game_tick(void)
{
 sound_event=0; entropy_frame();
 if(input_mine<10) {
  mine_number=input_mine; input_mine=255;
  start_game(); return;
 }
 if(mode==SELECT_MINE) {
  if(input_fire) { start_game(); sound_event=SND_EVADE; }
  return;
 }
 /* Return finishes entry; gameplay keys cannot edit a saved record name. */
 if(input_name==64) {
  if(name_cursor<6) {
   for(i=name_cursor;i<6;++i) name_chars[i]=12;
   name_changed=1;
  }
  name_cursor=255;
 } else if(input_name<46 && name_cursor!=255) {
  /* ROM $7bc clamps at the final character; it never wraps to the start. */
  name_chars[name_cursor<6 ? name_cursor : 5]=input_name;
  if(name_cursor<6) ++name_cursor;
  name_changed=1;
 }
 input_name=255;
 if(mode==ENTERING_MINE) {
  ++transition_clock; sound_queue=0xa0;
  if(!(transition_clock&3) && ++transition_stage==5) transition_stage=0;
  if(transition_clock==255) { difficulty>>=2; remove_floor(); new_round(); }
  else { pete_x=72; pete_y=104; input_x=input_y=0; input_fire=0; pete_step(); ++frame; }
  score_tick(); return;
 }
 if(mode==DYING) { input_x=0; input_y=1; input_fire=0; }
 if(!(frame&1)) {
  ladder_step();
  if(!on_ladder) pete_step(); else terrain=GAP;
 } else effect_step();
 spawn_rock();
 if(!(frame&1)) climb_step(); else pick_step();
 rock_step(); rock_step(); pick_rocks();
 if(frame&1) { item_step(); pete_contacts(); }
 else if(mode==DYING) {
  if(++death_clock>=96) { start_game(); return; }
  pete_shape=DEATH_0+(death_clock<32?1+((death_clock>>1)&3):0);
 }
 for(i=0;i<3;++i) {
  if(++door_clock[i]==0) { door_clock[i]=0; door_color[i]=(random_byte()>>1)&7; door_open[i]=0; }
 }
 score_tick(); ++frame;
}
