#include "engine.h"

#ifdef DEMO_BROKEN
/* Used by the demo data to produce a real failed build. */
#error "physics module not found: set DEMO_PHYSICS_DIR (intentional demo build failure)"
#endif

#include <stdio.h>
#include <string.h>

#define STR2(x) #x
#define STR(x) STR2(x)

static char version_text[160];

void world_init(World *world)
{
    memset(world, 0, sizeof(*world));
}

int world_spawn(World *world, float x, float y)
{
    if (world->count >= sizeof(world->entities) / sizeof(world->entities[0]))
        return -1;
    Entity *e = &world->entities[world->count];
    e->id = (int)world->count + 1;
    e->position.x = x;
    e->position.y = y;
    e->velocity.x = 1.5f - (float)(world->count % 3);
    e->velocity.y = 0.5f * (float)(world->count % 5);
    e->health = 100;
    return (int)world->count++;
}

static void entity_update(Entity *e, float dt)
{
    e->position.x += e->velocity.x * dt;
    e->position.y += e->velocity.y * dt;
    if (e->position.y > 100.0f) {
        e->health -= 25;
        e->velocity.y = -e->velocity.y;
    }
}

void world_step(World *world, float dt)
{
    for (size_t i = 0; i < world->count; i++)
        entity_update(&world->entities[i], dt);
    world->tick++;
}

int world_alive(const World *world)
{
    int alive = 0;
    for (size_t i = 0; i < world->count; i++)
        if (world->entities[i].health > 0)
            alive++;
    return alive;
}

unsigned long world_checksum(const World *world)
{
    unsigned long sum = world->tick;
    for (size_t i = 0; i < world->count; i++) {
        sum = sum * 31u + (unsigned long)world->entities[i].health;
        sum = sum * 31u + (unsigned long)(world->entities[i].position.x * 10.0f);
    }
    return sum;
}

const char *engine_version(void)
{
    snprintf(version_text, sizeof(version_text), "%s %s build %d (%.12s)",
             PROJECT, BRANCH, BUILD_NUMBER, REVISION);
    return version_text;
}

int engine_crash_test(World *world, int really_crash)
{
    Entity *broken = really_crash ? (Entity *)0 : &world->entities[0];
    return broken->health;
}
