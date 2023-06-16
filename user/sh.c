#include<unistd.h>
#include<stdio.h>
#include<sys/wait.h>
#include<sys/types.h>
#include<stdlib.h>
#include<string.h>
#define MAX_CMD 1024
#define MAX_DIR_NAME 1024
int buildin_command(char **argv){
    if(strcmp(argv[0],"exit")==0){
        exit(0);
    }
    if(strcmp(argv[0],"cd")==0){
        if(chdir(argv[1])){
            printf("cd error%s:no such directory\n",argv[1]);
        }
        return 1;
    }
    if(strcmp(argv[0],"pwd")==0){
        char buf[MAX_DIR_NAME];
        printf("%s\n",getcwd(buf,sizeof(buf)));
        return 1;
    }
    return 0;//not a buildin_command
}

void split(char *buf,char **argv)
{
    while(*buf==' '){
        buf++;
    }
    int delim = 0;
    int argc = 0;
    while(*buf != '\n'){
        while(buf[delim]!='\n' && buf[delim]!=' '){
            delim++;
        }
        if(buf[delim] == '\n'){
            buf[delim] = '\0';
            argv[argc++] = buf;
            break;
        }
        buf[delim] = '\0';
        argv[argc++] = buf;
        buf += delim + 1;
        delim = 0;
        while(*buf == ' ') buf++;
    }
    argv[argc] == NULL;
    
}


void mysys(char *str)
{
    char buf[1024];
    char **params;
    params = (char**)malloc(1024*sizeof(char*));
    strcpy(buf,str);
    split(buf,params);
    if(params[0] == NULL) return;
    if(buildin_command(params)) return;
    pid_t pid;
    pid = fork();
    if(pid == 0){
        if(execvp(params[0],params) < 0) {
            printf("command not found\n");
            exit(0);}

    }
    wait(NULL);
}

int main(int argc,char *argv[]){

    char cmdstring[MAX_CMD];
    int n;
    while(1){
        printf(">");
        fflush(stdout);

        /*read*/
        if((n=read(0,cmdstring,MAX_CMD))<0){
            printf("read error");
        }

        mysys(cmdstring);
    }
    return 0;
}
