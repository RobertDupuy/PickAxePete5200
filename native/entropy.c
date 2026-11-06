#include "game.h"
/* Free-running 8-bit counter and 5-bit prescaler. This is the original
   entropy mechanism, not a PRNG. The frame adapter supplies nominal NTSC
   source time; the routine oracle can instead supply exact cycle intervals.
   Starting phase is retained across new games, as on the cartridge. */
byte entropy_value, entropy_fraction;
static unsigned int elapsed;
static byte fifths;
void entropy_advance(byte cycles)
{
 unsigned int sum;
 elapsed+=cycles;
 sum=(unsigned int)entropy_fraction+cycles;
 entropy_value+=(byte)(sum>>5); entropy_fraction=(byte)sum&31;
}
byte random_byte(void)
{
 byte value;
 value=entropy_value; entropy_advance(1); return value;
}
void entropy_write(byte value) { entropy_value=value; }
void entropy_frame(void)
{
 unsigned int remainder;
 /* NTSC Atari: 262*114 clocks/frame. Source CPU machine-cycle clock
    is 1/5 of Atari's CPU clock: 5973 + 3/5 source cycles per frame.
    Preserve fractional phase; rounding to an even integer locks spawning. */
 fifths+=3;
 remainder=5973-elapsed+entropy_fraction;
 if(fifths>=5) { fifths-=5; ++remainder; }
 entropy_value+=(byte)(remainder>>5); entropy_fraction=(byte)remainder&31;
 elapsed=0;
}
