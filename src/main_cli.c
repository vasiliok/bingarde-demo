/* Console entry point for the Linux, Windows and macOS demo builds.
 *   demoapp              run a short simulation
 *   demoapp --version    print project, branch, build and revision
 *   demoapp --self-test  run the built-in checks, write JUnit XML to stdout
 *   demoapp --crash      crash on purpose (for crash-report demos) */
#include "engine.h"

#include <stdio.h>
#include <string.h>

static int check(const char *name, int ok, int *failures, char *xml, size_t xml_size)
{
    size_t used = strlen(xml);
    if (ok)
        snprintf(xml + used, xml_size - used, "    <testcase classname=\"engine\" name=\"%s\"/>\n", name);
    else
        snprintf(xml + used, xml_size - used,
                 "    <testcase classname=\"engine\" name=\"%s\"><failure message=\"check failed\"/></testcase>\n", name);
    if (!ok)
        (*failures)++;
    return ok;
}

static int self_test(void)
{
    static char cases[4096];
    int failures = 0, total = 0;
    World world;

    cases[0] = '\0';
    world_init(&world);
    total++; check("init_empty", world.count == 0, &failures, cases, sizeof(cases));
    for (int i = 0; i < 10; i++)
        world_spawn(&world, (float)i, 0.0f);
    total++; check("spawn_ten", world.count == 10, &failures, cases, sizeof(cases));
    for (int i = 0; i < 500; i++)
        world_step(&world, 0.1f);
    total++; check("step_ticks", world.tick == 500, &failures, cases, sizeof(cases));
    total++; check("some_alive", world_alive(&world) > 0, &failures, cases, sizeof(cases));
    total++; check("checksum_stable", world_checksum(&world) == world_checksum(&world), &failures, cases, sizeof(cases));
    total++; check("crash_test_safe", engine_crash_test(&world, 0) >= 0, &failures, cases, sizeof(cases));

    printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    printf("<testsuites>\n  <testsuite name=\"%s\" tests=\"%d\" failures=\"%d\">\n", engine_version(), total, failures);
    printf("%s", cases);
    printf("  </testsuite>\n</testsuites>\n");
    return failures ? 1 : 0;
}

int main(int argc, char **argv)
{
    if (argc > 1 && strcmp(argv[1], "--version") == 0) {
        puts(engine_version());
        return 0;
    }
    if (argc > 1 && strcmp(argv[1], "--self-test") == 0)
        return self_test();

    World world;
    world_init(&world);
    for (int i = 0; i < 20; i++)
        world_spawn(&world, (float)i * 2.0f, 0.0f);
    for (int i = 0; i < 1000; i++)
        world_step(&world, 0.05f);
    printf("%s: %d of %zu entities alive, checksum %lu\n",
           engine_version(), world_alive(&world), world.count, world_checksum(&world));

    if (argc > 1 && strcmp(argv[1], "--crash") == 0)
        return engine_crash_test(&world, 1);
    return 0;
}
