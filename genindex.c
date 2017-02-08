#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>

int main (int argc, char *argv[]) {
  char buffer[4096];
  char *ptr;
  int flag;

  /* Open up the input file for processing */
  if (argc != 2) {
    fprintf (stderr, "Requires one argument, a .index file generates by zimHttpServer.pl\n");
    exit(1);
  }
  FILE* input = fopen(argv[1], "r");
  if (input == NULL) {
    fprintf (stderr, "Could not open input file %s - %s\n", argv[1], strerror(errno));
    exit(1);
  }

  FILE* fp[26] = { NULL };
  char buf[128];
  for (char ch = 'a'; ch <= 'z'; ch++) {
    sprintf(buf, "%s.%c", argv[1], ch);
    fp[ch-'a'] = fopen(buf, "w");
    fprintf (stderr, "Writing out index file %s\n", buf);
  }
  
  while ((ptr = fgets(buffer, 4096, input )) != NULL) {
    int len = strlen(ptr);
    
    /* The index contains a lot of stuff I'm not interested in, like images. So only include
       lines that start with /A/ which is for articles */
    const int HEADER_SIZE = strlen("/A/");
    if (!((len > HEADER_SIZE) && (ptr[0] == '/') && (ptr[1] == 'A') && (ptr[2] == '/'))) {
      continue;
    }
    
    /* Find the first a-z character in the string and this will be the file it is indexed to */
    char first = '\0';
    for (char *c = ptr + HEADER_SIZE; *c != '\0'; c++) {
      char ch = tolower(*c);
      if ((ch >= 'a') && (ch <= 'z')) {
        first = ch;
        break;
      }
    }
    if (first == '\0') {
      fprintf (stderr, "Ignoring string since it has no ascii starting char [%s]\n", ptr);
      continue;
    }
    
    /* Write out this line to the appropriate matching file */
    fputs(ptr, fp[first-'a']);
  }

  for (char ch = 'a'; ch <= 'z'; ch++) {
    if (fclose(fp[ch-'a']) != 0) {
      fprintf(stderr, "Failed to close FILE for %c - %s\n", ch, strerror(errno));
      exit(1);
    }
  }
}
