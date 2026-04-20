// bench_branch.c — Branch-heavy benchmark for testing branch predictors
// Compiles for biriscv TCM testbench (bare-metal, no libc)
//
// Contains several patterns that stress branch prediction:
//   1. Tight counted loops (easily predicted)
//   2. Data-dependent branches (harder to predict)
//   3. Alternating taken/not-taken patterns
//   4. Nested loops with varying trip counts
//   5. Linked-list style pointer chasing

// Serial output via dscratch0 CSR (same mechanism as test.elf)
static void putchar_serial(char c)
{
    unsigned int val = (unsigned int)c | 0x01000000u;
    asm volatile("csrw dscratch0, %0" :: "r"(val));
}

static void puts_serial(const char *s)
{
    while (*s)
        putchar_serial(*s++);
}

static void put_dec(int n)
{
    if (n < 0) { putchar_serial('-'); n = -n; }
    if (n >= 10) put_dec(n / 10);
    putchar_serial('0' + (n % 10));
}

// Volatile to prevent optimizer from removing computation
static volatile int sink;

// ------------------------------------------------------------
// Test 1: Tight counted loops (predictable, trains the predictor)
// ------------------------------------------------------------
static int test_counted_loops(void)
{
    int sum = 0;
    for (int i = 0; i < 500; i++)          // 500 iterations — mostly taken
        sum += i;
    for (int i = 0; i < 300; i++)          // 300 iterations
        sum -= (i & 1) ? 1 : -1;
    return sum;
}

// ------------------------------------------------------------
// Test 2: Data-dependent branches (hard to predict)
// Uses a simple LFSR to generate pseudo-random taken/not-taken
// ------------------------------------------------------------
static int test_data_dependent(void)
{
    unsigned int lfsr = 0xACE1u;
    int count = 0;
    for (int i = 0; i < 1000; i++)
    {
        unsigned int bit = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1u;
        lfsr = (lfsr >> 1) | (bit << 15);
        if (lfsr & 1)                      // ~50% taken — very hard to predict
            count++;
        else
            count--;
    }
    return count;
}

// ------------------------------------------------------------
// Test 3: Alternating patterns (T,NT,T,NT,...)
// Bimodal predictors struggle; gshare/tournament can learn this
// ------------------------------------------------------------
static int test_alternating(void)
{
    int sum = 0;
    for (int i = 0; i < 800; i++)
    {
        if (i & 1)
            sum += 3;
        else
            sum += 7;
    }
    return sum;
}

// ------------------------------------------------------------
// Test 4: Nested loops with varying trip counts
// Inner loop count depends on outer — stresses BHT aliasing
// ------------------------------------------------------------
static int test_nested_loops(void)
{
    int sum = 0;
    for (int i = 1; i <= 30; i++)
    {
        for (int j = 0; j < i; j++)
            sum += j;
    }
    return sum;
}

// ------------------------------------------------------------
// Test 5: Correlated branches
// The outcome of branch B depends on the outcome of branch A
// Two-level / gshare / tournament predictors can learn this
// ------------------------------------------------------------
static int test_correlated(void)
{
    int sum = 0;
    for (int i = 0; i < 600; i++)
    {
        int a = (i % 3) == 0;              // branch A: taken every 3rd iter
        int b;
        if (a)
            b = 1;                          // branch B: always taken when A was taken
        else
            b = (i & 1);                    // branch B: alternating when A not taken

        if (b)
            sum += 2;
        else
            sum -= 1;
    }
    return sum;
}

// ------------------------------------------------------------
// Test 6: Switch-like cascaded branches (if-else chain)
// Common in interpreters / dispatch loops
// ------------------------------------------------------------
static int test_switch_like(void)
{
    int sum = 0;
    for (int i = 0; i < 500; i++)
    {
        int mod = i % 7;
        if (mod == 0)      sum += 1;
        else if (mod == 1) sum += 2;
        else if (mod == 2) sum += 3;
        else if (mod == 3) sum -= 1;
        else if (mod == 4) sum -= 2;
        else if (mod == 5) sum += 5;
        else               sum -= 3;
    }
    return sum;
}

// ------------------------------------------------------------
// Test 7: Bubble sort — classic branch-heavy algorithm
// Many data-dependent conditional swaps
// ------------------------------------------------------------
static int test_bubble_sort(void)
{
    int arr[50];
    // Fill in reverse order
    for (int i = 0; i < 50; i++)
        arr[i] = 50 - i;

    // Bubble sort
    for (int i = 0; i < 49; i++)
    {
        for (int j = 0; j < 49 - i; j++)
        {
            if (arr[j] > arr[j + 1])       // data-dependent branch
            {
                int tmp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = tmp;
            }
        }
    }
    return arr[0] + arr[49];
}

// ============================================================
// Main
// ============================================================
int main(void)
{
    int result;

    puts_serial("\n=== Branch Predictor Benchmark ===\n");

    puts_serial("Test 1: Counted loops ... ");
    result = test_counted_loops();
    sink = result;
    put_dec(result);
    putchar_serial('\n');

    puts_serial("Test 2: Data-dependent (LFSR) ... ");
    result = test_data_dependent();
    sink = result;
    put_dec(result);
    putchar_serial('\n');

    puts_serial("Test 3: Alternating T/NT ... ");
    result = test_alternating();
    sink = result;
    put_dec(result);
    putchar_serial('\n');

    puts_serial("Test 4: Nested loops ... ");
    result = test_nested_loops();
    sink = result;
    put_dec(result);
    putchar_serial('\n');

    puts_serial("Test 5: Correlated branches ... ");
    result = test_correlated();
    sink = result;
    put_dec(result);
    putchar_serial('\n');

    puts_serial("Test 6: Switch-like cascade ... ");
    result = test_switch_like();
    sink = result;
    put_dec(result);
    putchar_serial('\n');

    puts_serial("Test 7: Bubble sort ... ");
    result = test_bubble_sort();
    sink = result;
    put_dec(result);
    putchar_serial('\n');

    puts_serial("=== DONE ===\n");

    return 0;
}
