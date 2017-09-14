enum class e:int{a,b,c};
int f(int* i, e* j) {
    *i = 1;
    *j = (e)2;
    return *i;
}

int g(){
    e a;
    return f((int *)&a,&a);
}



void foo (char* a, int d) {
    reinterpret_cast<int*>(a)[1] = d;
}
#include <cstring>
void bar (char* a, int d) {
    memcpy(a+4, &d, sizeof(d));
}

struct data {
    int a;
    double b;
    char* c;
};

#include <cstring>

int foo(char* d) {
    return strlen(((data*)d)->c);
}


int bar(char* a) {
    data d;
    memcpy(&d, a, sizeof(d));
    return strlen(d.c);
}


int cast(char* a, char* b, bool sign) {
    if (sign)
        return (*(int*)a) * (*(int*)b);
    return (*(unsigned*)a) * (*(unsigned*)b);
}


int copy(char* a, char* b, bool sign) {
    if (sign) {
        int as, bs;
        memcpy(&as, a, sizeof(int));
        memcpy(&bs, b, sizeof(int));
        return as * bs;
    }

    unsigned as, bs;
    memcpy(&as, a, sizeof(int));
    memcpy(&bs, b, sizeof(int));
    return as * bs;
}


int foo(int *i, double *d) {
    int ii;
        double dd;

    ii = *i;
        *i *= 2;
            dd = *d;
                *d *= 2;
                    ii = *i;
                        *i *= 2;
                            dd = *d;
                                *d *= 2;
                                    ii = *i;
                                        *i *= 2;
                                            dd = *d;
                                                *d *= 2;
                                                    ii = *i;
                                                        *i *= 2;
                                                            dd = *d;
                                                                *d *= 2;
                                                                    ii = *i;
                                                                        *i *= 2;
                                                                            dd = *d;
                                                                                *d *= 2;
                                                                                    ii = *i;
                                                                                        *i *= 2;
                                                                                            dd = *d;
                                                                                                *d *= 2;
                                                                                                    ii = *i;
                                                                                                        *i *= 2;
                                                                                                            dd = *d;
                                                                                                                *d *= 2;
                                                                                                                    return ii * dd;
                                                                                                                    }

https://blog.regehr.org/archives/1307
