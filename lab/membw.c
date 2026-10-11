// Measure how fast 1..4 threads can read from RAM.
// Generation in llama.cpp streams all weights once per token, so this read
// speed is its ceiling. The buffer is far bigger than the 6 MB L3 cache.
//
// Build and run (on the Mac):
//   cc -O2 -mavx2 -pthread lab/membw.c -o wt/membw && wt/membw

#include <immintrin.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define SIZE (1024L * 1024 * 1024)  // 1 GiB
#define REPS 5

static char * buf;

struct job {
    long      begin, end;
    long long sum;  // printed, so the compiler can't skip the reads
};

static void * reader(void * arg) {
    struct job * j = arg;
    __m256i a0 = _mm256_setzero_si256(), a1 = a0, a2 = a0, a3 = a0;
    for (long i = j->begin; i < j->end; i += 128) {  // 4 loads of 32 bytes
        a0 = _mm256_add_epi64(a0, _mm256_load_si256((const __m256i *) (buf + i)));
        a1 = _mm256_add_epi64(a1, _mm256_load_si256((const __m256i *) (buf + i + 32)));
        a2 = _mm256_add_epi64(a2, _mm256_load_si256((const __m256i *) (buf + i + 64)));
        a3 = _mm256_add_epi64(a3, _mm256_load_si256((const __m256i *) (buf + i + 96)));
    }
    a0 = _mm256_add_epi64(_mm256_add_epi64(a0, a1), _mm256_add_epi64(a2, a3));
    long long t[4];
    _mm256_storeu_si256((__m256i *) t, a0);
    j->sum = t[0] + t[1] + t[2] + t[3];
    return NULL;
}

static double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

int main(void) {
    if (posix_memalign((void **) &buf, 64, SIZE) != 0) {
        return 1;
    }
    memset(buf, 1, SIZE);  // touch every page before timing

    printf("read bandwidth, 1 GiB buffer, best and mean of %d runs\n", REPS);
    for (int nth = 1; nth <= 4; nth++) {
        double best = 0, total = 0;
        long long check = 0;
        for (int r = 0; r < REPS; r++) {
            pthread_t  th[4];
            struct job jobs[4];
            long       slice = SIZE / nth / 128 * 128;
            double     t0    = now();
            for (int i = 0; i < nth; i++) {
                jobs[i].begin = i * slice;
                jobs[i].end   = i == nth - 1 ? SIZE : (i + 1) * slice;
                pthread_create(&th[i], NULL, reader, &jobs[i]);
            }
            for (int i = 0; i < nth; i++) {
                pthread_join(th[i], NULL);
                check += jobs[i].sum;
            }
            double gbs = SIZE / 1e9 / (now() - t0);
            total += gbs;
            if (gbs > best) {
                best = gbs;
            }
        }
        printf("threads %d: best %5.1f GB/s, mean %5.1f GB/s  (check %lld)\n",
               nth, best, total / REPS, check);
    }
    free(buf);
    return 0;
}
