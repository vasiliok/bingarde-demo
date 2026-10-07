/* A tiny "game engine" for demo builds: enough real functions and types
 * that the debug symbols (PDB, DWARF .debug, dSYM) have meaningful content. */
#ifndef DEMO_ENGINE_H
#define DEMO_ENGINE_H

#include <stddef.h>

#ifndef PROJECT
#define PROJECT "demo"
#endif
#ifndef BRANCH
#define BRANCH "main"
#endif
#ifndef BUILD_NUMBER
#define BUILD_NUMBER 0
#endif
#ifndef REVISION
#define REVISION "0000000000000000000000000000000000000000"
#endif

typedef struct {
    float x, y;
} Vec2;

typedef struct {
    int id;
    Vec2 position;
    Vec2 velocity;
    int health;
} Entity;

typedef struct {
    Entity entities[64];
    size_t count;
    unsigned long tick;
} World;

void world_init(World *world);
int world_spawn(World *world, float x, float y);
void world_step(World *world, float dt);
int world_alive(const World *world);
unsigned long world_checksum(const World *world);
const char *engine_version(void);

/* Walks a damaged entity list; crashes on purpose when asked to, so a
 * crash report would point into the symbols. */
int engine_crash_test(World *world, int really_crash);

#endif
