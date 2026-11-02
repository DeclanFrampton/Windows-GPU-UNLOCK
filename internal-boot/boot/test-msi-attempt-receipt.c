#include <Uefi.h>
#include <Protocol/SimpleFileSystem.h>
#include "msi-attempt-receipt.h"
typedef struct {EFI_FILE_PROTOCOL io;BOOLEAN exists;UINTN n;char data[96];} FILE_MOCK;
static FILE_MOCK Files[3];static EFI_FILE_PROTOCOL RootMock;static unsigned Mode,Creates,Deletes;
static EFI_STATUS EFIAPI Close(EFI_FILE_PROTOCOL *f){(void)f;return Mode==9?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI Read(EFI_FILE_PROTOCOL *f,UINTN *n,VOID *out){FILE_MOCK *m=(FILE_MOCK *)f;if(Mode==11)return EFI_DEVICE_ERROR;if(*n<m->n)return EFI_BAD_BUFFER_SIZE;*n=m->n;for(UINTN i=0;i<*n;i++)((char *)out)[i]=m->data[i];if(Mode==7 && m==&Files[1])((char *)out)[0]='?';return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Write(EFI_FILE_PROTOCOL *f,UINTN *n,VOID *in){FILE_MOCK *m=(FILE_MOCK *)f;if(Mode==5)(*n)--;m->n=*n;for(UINTN i=0;i<*n;i++)m->data[i]=((char *)in)[i];return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Flush(EFI_FILE_PROTOCOL *f){(void)f;return Mode==6?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI Delete(EFI_FILE_PROTOCOL *f){Deletes++;if(Mode==8)return EFI_DEVICE_ERROR;((FILE_MOCK *)f)->exists=FALSE;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Open(EFI_FILE_PROTOCOL *r,EFI_FILE_PROTOCOL **out,CHAR16 *path,UINT64 flags,UINT64 attrs){
 (void)r;(void)attrs;unsigned index=path[0]=='A'?0:path[0]=='S'?1:2;FILE_MOCK *m=&Files[index];*out=NULL;
 if(flags&EFI_FILE_MODE_CREATE){Creates++;if(Mode==10)return EFI_DEVICE_ERROR;m->exists=TRUE;}
 if(!m->exists)return EFI_NOT_FOUND;*out=&m->io;return EFI_SUCCESS;
}
int main(void){
 const char *id="0123456789abcdef0123456789abcdef";
 for(unsigned mode=0;mode<13;mode++){
  Mode=mode;Creates=Deletes=0;
  for(unsigned j=0;j<3;j++){Files[j]=(FILE_MOCK){0};Files[j].io.Close=Close;Files[j].io.Read=Read;Files[j].io.Write=Write;Files[j].io.Flush=Flush;Files[j].io.Delete=Delete;}
  RootMock.Open=Open;Files[0].exists=mode!=1;Files[0].n=38;
  const char *prefix="ARM ";for(unsigned j=0;j<4;j++)Files[0].data[j]=prefix[j];for(unsigned j=0;j<32;j++)Files[0].data[4+j]=id[j];Files[0].data[36]='\r';Files[0].data[37]='\n';
  if(mode==2)Files[0].data[4]='f';if(mode==3)Files[1].exists=TRUE;if(mode==4)Files[2].exists=TRUE;if(mode==12)Files[0].n++;
  EFI_STATUS s=GuMsiAttemptBegin(&RootMock,L"A",L"S",L"F",id);
  if(mode==0){if(s!=EFI_SUCCESS || !Files[1].exists || Files[0].exists || Deletes!=1)return 1;
   if(GuMsiAttemptBegin(&RootMock,L"A",L"S",L"F",id)==EFI_SUCCESS)return 2;
   if(GuMsiAttemptFinish(&RootMock,L"S",L"F",id)!=EFI_SUCCESS || !Files[2].exists)return 3;
   if(GuMsiAttemptFinish(&RootMock,L"S",L"F",id)==EFI_SUCCESS)return 4;
  }else if(s==EFI_SUCCESS)return 10+mode;
  if((mode==1 || mode==2 || mode==3 || mode==4 || mode==12) && Creates)return 30+mode;
  if(mode==8 && !Files[1].exists)return 50;
 }
 for(unsigned mode=5;mode<=11;mode++){
  if(mode==8)continue;
  Mode=0;for(unsigned j=0;j<3;j++){Files[j].exists=FALSE;Files[j].n=0;}
  const char *prefix="ARM ";Files[0].exists=TRUE;Files[0].n=38;
  for(unsigned j=0;j<4;j++)Files[0].data[j]=prefix[j];for(unsigned j=0;j<32;j++)Files[0].data[4+j]=id[j];Files[0].data[36]='\r';Files[0].data[37]='\n';
  if(GuMsiAttemptBegin(&RootMock,L"A",L"S",L"F",id)!=EFI_SUCCESS)return 60;
  Mode=mode;if(GuMsiAttemptFinish(&RootMock,L"S",L"F",id)==EFI_SUCCESS)return 60+mode;
 }
 return 0;
}
