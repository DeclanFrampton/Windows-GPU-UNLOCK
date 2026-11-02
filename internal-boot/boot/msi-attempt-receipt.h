/* Durable exact-attempt latch. Filesystem-only; no hardware operations. */
#pragma once
static EFI_STATUS MsiAbsent(EFI_FILE_PROTOCOL *root,CHAR16 *path){
 EFI_FILE_PROTOCOL *f=NULL;EFI_STATUS s=root->Open(root,&f,path,EFI_FILE_MODE_READ,0);
 if(s==EFI_NOT_FOUND)return EFI_SUCCESS;
 if(s==EFI_SUCCESS && f && f->Close)f->Close(f);
 return s==EFI_SUCCESS?EFI_ALREADY_STARTED:s;
}
static EFI_STATUS MsiReadExact(EFI_FILE_PROTOCOL *root,CHAR16 *path,const char *expected,UINTN length){
 EFI_FILE_PROTOCOL *f=NULL;EFI_STATUS s=root->Open(root,&f,path,EFI_FILE_MODE_READ,0);
 if(s!=EFI_SUCCESS || !f)return s==EFI_SUCCESS?EFI_DEVICE_ERROR:s;
 char bytes[96];UINTN n=sizeof(bytes);
 if(!f->Read || !f->Close)s=EFI_UNSUPPORTED;
 else {s=f->Read(f,&n,bytes);if(s==EFI_SUCCESS){if(n!=length)s=EFI_COMPROMISED_DATA;else for(UINTN i=0;i<n;i++)if(bytes[i]!=expected[i])s=EFI_COMPROMISED_DATA;}}
 EFI_STATUS closed=f->Close?f->Close(f):EFI_UNSUPPORTED;return s==EFI_SUCCESS?closed:s;
}
static EFI_STATUS MsiNewReceipt(EFI_FILE_PROTOCOL *root,CHAR16 *path,const char *text,UINTN length){
 EFI_STATUS s=MsiAbsent(root,path);if(s!=EFI_SUCCESS)return s;
 EFI_FILE_PROTOCOL *f=NULL;s=root->Open(root,&f,path,EFI_FILE_MODE_CREATE|EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE,0);
 if(s!=EFI_SUCCESS || !f)return s==EFI_SUCCESS?EFI_DEVICE_ERROR:s;
 UINTN n=length;
 if(!f->Write || !f->Flush || !f->Close)s=EFI_UNSUPPORTED;
 else {s=f->Write(f,&n,(VOID *)text);if(s==EFI_SUCCESS && n!=length)s=EFI_DEVICE_ERROR;if(s==EFI_SUCCESS)s=f->Flush(f);}
 EFI_STATUS closed=f->Close?f->Close(f):EFI_UNSUPPORTED;if(s==EFI_SUCCESS)s=closed;
 return s==EFI_SUCCESS?MsiReadExact(root,path,text,length):s;
}
static EFI_STATUS GuMsiAttemptBegin(EFI_FILE_PROTOCOL *root,CHAR16 *armPath,CHAR16 *startPath,CHAR16 *finishPath,const char *id){
 if(!root || !root->Open || !id)return EFI_INVALID_PARAMETER;
 for(UINTN i=0;i<32;i++)if(!((id[i]>='0'&&id[i]<='9')||(id[i]>='a'&&id[i]<='f')))return EFI_INVALID_PARAMETER;
 if(id[32])return EFI_INVALID_PARAMETER;
 char arm[38]="ARM ",started[42]="STARTED ";
 for(UINTN i=0;i<32;i++){arm[4+i]=id[i];started[8+i]=id[i];}
 arm[36]='\r';arm[37]='\n';started[40]='\r';started[41]='\n';
 EFI_STATUS s=MsiAbsent(root,startPath);if(s==EFI_SUCCESS)s=MsiAbsent(root,finishPath);
 if(s==EFI_SUCCESS)s=MsiReadExact(root,armPath,arm,sizeof(arm));
 if(s==EFI_SUCCESS)s=MsiNewReceipt(root,startPath,started,sizeof(started));
 /* A STARTED receipt remains even when consuming the arm fails. Never retry. */
 EFI_FILE_PROTOCOL *f=NULL;if(s==EFI_SUCCESS)s=root->Open(root,&f,armPath,EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE,0);
 if(s==EFI_SUCCESS){if(!f || !f->Delete){if(f && f->Close)f->Close(f);s=EFI_UNSUPPORTED;}else s=f->Delete(f);}
 return s;
}
static EFI_STATUS GuMsiAttemptFinish(EFI_FILE_PROTOCOL *root,CHAR16 *startPath,CHAR16 *finishPath,const char *id){
 char started[42]="STARTED ",finished[43]="FINISHED ";
 for(UINTN i=0;i<32;i++){started[8+i]=id[i];finished[9+i]=id[i];}
 started[40]='\r';started[41]='\n';finished[41]='\r';finished[42]='\n';
 EFI_STATUS s=MsiReadExact(root,startPath,started,sizeof(started));
 return s==EFI_SUCCESS?MsiNewReceipt(root,finishPath,finished,sizeof(finished)):s;
}
