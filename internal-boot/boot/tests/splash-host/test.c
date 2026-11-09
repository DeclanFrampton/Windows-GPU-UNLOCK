/* SPDX-License-Identifier: GPL-2.0-only
 * Hosted CPU-only test of the actual player, not a decoder model. */
#if !defined(__STDC_HOSTED__) || !__STDC_HOSTED__ || !defined(GU_SPLASH_HOST_TEST)
#error "Splash harness requires a hosted build and GU_SPLASH_HOST_TEST"
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef NULL
/* GCC lacks Clang's non-temporal-store builtin. This changes memory-store
 * semantics only in this test translation unit, not production source. */
static size_t HostVectorStores;
#define __builtin_nontemporal_store(value, pointer) \
 do { *(pointer) = (value); HostVectorStores++; } while(0)
#include "../../boot-splash.c"
#include "../../../unlock/sha256.c"

static unsigned Checks;
#define CHECK(c) do { Checks++; if(!(c)){fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#c);exit(1);} } while(0)
static UINT8 *Fixture, *Ram;
static UINTN FixtureSize, Position;
static unsigned AllocCalls, LivePools, FailAlloc, NullAlloc, Reads, ShortRead;
static unsigned Blts, Closes, Events, EventCalls, FailEvent, TimerCalls, FailTimer;
static BOOLEAN Escape, FailWait, FailBlt, FailClose, ExtraByte, FailOpen, FailRead, UnicodeEscape, FailKey;
static unsigned TickWaits;
static EFI_GRAPHICS_OUTPUT_MODE_INFORMATION Info;
static EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE TestMode;
static EFI_GRAPHICS_OUTPUT_PROTOCOL TestGop;
static EFI_TIMESTAMP_PROTOCOL TestClock;
static EFI_FILE_PROTOCOL File, Volume;
static EFI_BOOT_SERVICES Bs;
static EFI_SIMPLE_TEXT_INPUT_PROTOCOL Input;
static EFI_SYSTEM_TABLE Table;
static UINT64 Time;
static EFI_STATUS EFIAPI Alloc(EFI_MEMORY_TYPE type,UINTN n,VOID **p){
 (void)type; *p=NULL; AllocCalls++;
 if(AllocCalls==FailAlloc)return EFI_OUT_OF_RESOURCES;
 if(AllocCalls==NullAlloc)return EFI_SUCCESS;
 CHECK(n<=GU_SPLASH_BYTES+MATRIX_PIXELS*sizeof(PIXEL));
 *p=malloc(n);CHECK(*p!=NULL);LivePools++;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Free(VOID *p){CHECK(p&&LivePools);free(p);LivePools--;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Open(EFI_FILE_PROTOCOL *self,EFI_FILE_PROTOCOL **p,CHAR16 *name,UINT64 mode,UINT64 attrs){
 CHECK(self==&Volume&&name&&mode==EFI_FILE_MODE_READ&&!attrs);Position=0;*p=&File;return FailOpen?EFI_NOT_FOUND:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Read(EFI_FILE_PROTOCOL *self,UINTN *n,VOID *p){
 CHECK(self==&File);Reads++;if(FailRead)return EFI_DEVICE_ERROR;
 UINTN left=FixtureSize-Position;if(*n>left)*n=left;
 if(Reads==ShortRead&&*n)(*n)--;
 memcpy(p,Fixture+Position,*n);Position+=*n;
 if(ExtraByte&&!*n){*(UINT8*)p=1;*n=1;}
 return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Close(EFI_FILE_PROTOCOL *self){CHECK(self==&File);Closes++;return FailClose?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static UINT64 EFIAPI Timestamp(VOID){Time+=1000;return Time;}
static EFI_STATUS EFIAPI Properties(EFI_TIMESTAMP_PROPERTIES *p){p->Frequency=1000000;p->EndValue=~(UINT64)0;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Locate(EFI_GUID *g,VOID *r,VOID **p){(void)g;(void)r;*p=&TestClock;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Handle(EFI_HANDLE h,EFI_GUID *g,VOID **p){(void)h;(void)g;*p=&TestGop;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Handles(EFI_LOCATE_SEARCH_TYPE t,EFI_GUID *g,VOID *k,UINTN *n,EFI_HANDLE **p){(void)t;(void)g;(void)k;*n=0;*p=NULL;return EFI_NOT_FOUND;}
static EFI_STATUS EFIAPI Blt(EFI_GRAPHICS_OUTPUT_PROTOCOL *g,PIXEL *p,EFI_GRAPHICS_OUTPUT_BLT_OPERATION op,UINTN sx,UINTN sy,UINTN dx,UINTN dy,UINTN w,UINTN h,UINTN delta){
 CHECK(g==&TestGop&&St&&Visible&&p);CHECK(dx+w<=Info.HorizontalResolution&&dy+h<=Info.VerticalResolution);
 if(op==EfiBltBufferToVideo){CHECK(sx+w<=MATRIX_WIDTH&&sy+h<=MATRIX_HEIGHT&&delta==MATRIX_WIDTH*sizeof(PIXEL));}
 else CHECK(op==EfiBltVideoFill);
 Blts++;return FailBlt?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Key(EFI_SIMPLE_TEXT_INPUT_PROTOCOL *i,EFI_INPUT_KEY *k){CHECK(i==&Input);k->ScanCode=Escape?0x17:0;k->UnicodeChar=UnicodeEscape?27:0;return FailKey?EFI_DEVICE_ERROR:((Escape||UnicodeEscape)?EFI_SUCCESS:EFI_NOT_READY);}
static EFI_STATUS EFIAPI Create(UINT32 t,EFI_TPL tpl,EFI_EVENT_NOTIFY f,VOID *c,EFI_EVENT *e){
 (void)t;(void)tpl;CHECK(!f&&!c);EventCalls++;*e=NULL;if(EventCalls==FailEvent)return EFI_OUT_OF_RESOURCES;
 *e=malloc(1);CHECK(*e!=NULL);Events++;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Timer(EFI_EVENT e,EFI_TIMER_DELAY d,UINT64 t){CHECK(e&&(d==TimerRelative||d==TimerPeriodic)&&t);TimerCalls++;return TimerCalls==FailTimer?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI Wait(UINTN n,EFI_EVENT *events,UINTN *i){CHECK((n==2||n==3)&&events[0]&&events[1]);*i=TickWaits?1:0;if(TickWaits){TickWaits--;Time+=33334;}return FailWait?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI CloseEvent(EFI_EVENT e){CHECK(e&&Events);free(e);Events--;return EFI_SUCCESS;}

static void Reset(void){
 CHECK(GuBootSplashEnd()==EFI_SUCCESS);CHECK(!LivePools&&!Events);
 AllocCalls=FailAlloc=NullAlloc=Reads=ShortRead=Blts=Closes=EventCalls=FailEvent=TimerCalls=FailTimer=0;
 Escape=FailWait=FailBlt=FailClose=ExtraByte=FailOpen=FailRead=UnicodeEscape=FailKey=FALSE;Time=0;TickWaits=0;
 Info=(EFI_GRAPHICS_OUTPUT_MODE_INFORMATION){0};Info.HorizontalResolution=MATRIX_WIDTH;Info.VerticalResolution=MATRIX_HEIGHT;
 Info.PixelsPerScanLine=MATRIX_WIDTH;Info.PixelFormat=PixelBlueGreenRedReserved8BitPerColor;
 TestMode=(EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE){0};TestMode.Info=&Info;TestMode.SizeOfInfo=sizeof(Info);
 TestMode.FrameBufferBase=(UINT64)(UINTN)(Ram+16);TestMode.FrameBufferSize=MATRIX_PIXELS*sizeof(PIXEL);
 memset(Ram,0xa5,MATRIX_PIXELS*sizeof(PIXEL)+32);
 TestGop=(EFI_GRAPHICS_OUTPUT_PROTOCOL){0};TestGop.Mode=&TestMode;TestGop.Blt=Blt;
 TestClock.GetTimestamp=Timestamp;TestClock.GetProperties=Properties;
 Volume.Open=Open;File.Read=Read;File.Close=Close;
 Bs=(EFI_BOOT_SERVICES){0};Bs.AllocatePool=Alloc;Bs.FreePool=Free;Bs.LocateProtocol=Locate;Bs.HandleProtocol=Handle;Bs.LocateHandleBuffer=Handles;
 Bs.CreateEvent=Create;Bs.SetTimer=Timer;Bs.WaitForEvent=Wait;Bs.CloseEvent=CloseEvent;
 Input.ReadKeyStroke=Key;Input.WaitForKey=(EFI_EVENT)&Input;
 Table=(EFI_SYSTEM_TABLE){0};Table.BootServices=&Bs;Table.ConIn=&Input;
}
static void End(void){
 CHECK(GuBootSplashEnd()==EFI_SUCCESS);CHECK(!LivePools&&!Events&&!GuBootSplashVisible());
 unsigned before=Blts;BOOLEAN skip=TRUE;CHECK(GuBootSplashPlay(TRUE,&skip)==EFI_INVALID_PARAMETER);
 MatrixDraw(0);CHECK(GuBootSplashEnd()==EFI_SUCCESS);CHECK(Blts==before);
 for(unsigned i=0;i<16;i++)CHECK(Ram[i]==0xa5&&Ram[MATRIX_PIXELS*sizeof(PIXEL)+16+i]==0xa5);
}
static UINTN Block(UINT8 *p,UINTN count){
 /* One literal followed by an overlapping distance-one match. */
 p[0]=0x1f;p[1]=0x5a;p[2]=1;p[3]=0;UINTN n=4,extra=count-6-4-15;
 while(extra>=255){p[n++]=255;extra-=255;}p[n++]=(UINT8)extra;p[n++]=0x50;
 for(unsigned i=0;i<5;i++)p[n++]=0x5a;
 return n;
}
static void FixtureInit(void){
 FixtureSize=GU_SPLASH_BYTES;Fixture=malloc(FixtureSize);CHECK(Fixture!=NULL);
 UINT32 *h=(UINT32*)Fixture;h[0]=0x414d5547;h[1]=0x31305854;h[2]=MATRIX_WIDTH;h[3]=MATRIX_HEIGHT;h[4]=MATRIX_FRAMES;
 UINTN len=Block(Fixture+118*4,MATRIX_PIXELS*2);
 for(unsigned i=0;i<=MATRIX_FRAMES;i++)h[5+i]=(UINT32)(i*len);
 for(unsigned i=1;i<MATRIX_FRAMES;i++)memcpy(Fixture+118*4+i*len,Fixture+118*4,len);
 CHECK(118*4+len*MATRIX_FRAMES==FixtureSize);CHECK(GuHashMatches(Fixture,FixtureSize,GU_SPLASH_SHA256));
}
static void DecoderTests(void){
 UINTN cap=MATRIX_PIXELS*2;UINT8 *out=malloc(cap+32),*src=malloc(cap+20000);CHECK(out&&src);memset(out,0xa5,cap+32);
 UINTN n=Block(src,cap);CHECK(MatrixDecode(src,n,(UINT16*)(out+16)));for(UINTN i=16;i<cap+16;i++)CHECK(out[i]==0x5a);
 CHECK(!MatrixDecode(src,n-1,(UINT16*)(out+16)));n=Block(src,cap+1);CHECK(!MatrixDecode(src,n,(UINT16*)(out+16)));
 n=Block(src,cap+6);CHECK(!MatrixDecode(src,n,(UINT16*)(out+16)));
 const UINT8 bad[][5]={{0xf0},{0x10},{0x10,1,0},{0x10,1,0,0},{0x10,1,2,0},{0x1f,1,1,0},{0x20,1}};
 const UINTN sizes[]={1,1,3,4,4,4,2};for(unsigned i=0;i<sizeof(sizes)/sizeof(*sizes);i++)CHECK(!MatrixDecode(bad[i],sizes[i],(UINT16*)(out+16)));
 CHECK(!MatrixDecode(src,0,(UINT16*)(out+16)));
 /* Full literal block, then one-byte-overflow literal length. */
 UINTN k=0;src[k++]=0xf0;UINTN extra=cap-15;while(extra>=255){src[k++]=255;extra-=255;}src[k++]=(UINT8)extra;memset(src+k,0x69,cap);
 CHECK(MatrixDecode(src,k+cap,(UINT16*)(out+16)));
 for(UINTN i=16;i<cap+16;i++)CHECK(out[i]==0x69);
 src[k-1]++;src[k+cap]=0;CHECK(!MatrixDecode(src,k+cap+1,(UINT16*)(out+16)));
 for(unsigned i=0;i<16;i++)CHECK(out[i]==0xa5&&out[cap+16+i]==0xa5);
 free(out);free(src);
}
static void LoadTests(void){
 UINT32 *h=(UINT32*)Fixture;
 Reset();FailOpen=TRUE;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_NOT_FOUND);CHECK(!Closes&&!Blts);End();
 Reset();FailRead=TRUE;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_DEVICE_ERROR);CHECK(Closes==1&&!Blts);End();
 for(unsigned i=0;i<6;i++){Reset();UINT32 old=h[i];h[i]^=1;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_COMPROMISED_DATA);h[i]=old;CHECK(Closes==1&&!Blts);End();}
 const unsigned pos[]={6,6,6,117};const UINT32 values[]={0,MATRIX_LIMIT+1,MATRIX_PIXELS*2+65537,0};
 for(unsigned i=0;i<4;i++){Reset();UINT32 old=h[pos[i]];h[pos[i]]=values[i];CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_COMPROMISED_DATA);h[pos[i]]=old;End();}
 Reset();h[117]--;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_COMPROMISED_DATA);h[117]++;End();
 for(unsigned i=1;i<=3;i++){Reset();ShortRead=i;CHECK(GuBootSplashBegin(&Table,&Volume)!=(EFI_STATUS)EFI_SUCCESS);CHECK(Closes==1&&!Blts);End();}
 Reset();ExtraByte=TRUE;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_COMPROMISED_DATA);End();
 Reset();Fixture[FixtureSize-1]^=1;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_CRC_ERROR);Fixture[FixtureSize-1]^=1;End();
 Reset();FailClose=TRUE;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_DEVICE_ERROR);End();
 for(unsigned i=1;i<=4;i++){Reset();FailAlloc=i;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_OUT_OF_RESOURCES);CHECK(!Blts);End();Reset();NullAlloc=i;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_OUT_OF_RESOURCES);End();}
}
static void LifecycleTests(void){
 Reset();CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_SUCCESS);CHECK(GuBootSplashVisible()&&GuBootSplashFrames()==1);CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_UNSUPPORTED);
 unsigned old=Blts;MatrixDraw(1);CHECK(GuBootSplashFrames()==2&&Blts==old); // unchanged tiles
 BOOLEAN skip=FALSE;Escape=TRUE;CHECK(GuBootSplashPlay(TRUE,&skip)==EFI_SUCCESS&&skip&&!Events);End();
 Reset();CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_SUCCESS);UnicodeEscape=TRUE;CHECK(GuBootSplashPlay(TRUE,&skip)==EFI_SUCCESS&&skip);End();
 Reset();CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_SUCCESS);FailKey=TRUE;CHECK(GuBootSplashPlay(TRUE,&skip)==EFI_DEVICE_ERROR);End();
 Reset();CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_SUCCESS);TickWaits=3;CHECK(GuBootSplashPlay(TRUE,&skip)==EFI_SUCCESS);CHECK(GuBootSplashFrames()==4);End();
 for(unsigned kind=0;kind<5;kind++){Reset();CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_SUCCESS);if(kind<2)FailEvent=kind+1;else if(kind<4)FailTimer=kind-1;else FailWait=TRUE;CHECK(GuBootSplashPlay(TRUE,&skip)!=EFI_SUCCESS);CHECK(!Events);End();}
 Reset();CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_SUCCESS);CHECK(GuBootSplashPlay(FALSE,&skip)==EFI_SUCCESS);CHECK(MatrixFrame==111&&!Events);End();
 Reset();CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_SUCCESS);Info.HorizontalResolution++;old=Blts;MatrixDraw(1);CHECK(!Visible&&Blts==old);End();
 Reset();FailBlt=TRUE;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_DEVICE_ERROR);End();
 Reset();Info.PixelFormat=PixelFormatMax;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_UNSUPPORTED);End();
 Reset();Info.PixelFormat=PixelBltOnly;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_SUCCESS);CHECK(!GuBootSplashDirect());End();
 Reset();Bs.LocateProtocol=NULL;CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_UNSUPPORTED);End();
}
static void FramebufferTests(void){
 Reset();CHECK(GuBootSplashBegin(&Table,&Volume)==EFI_SUCCESS);MATRIX_FRAMEBUFFER s;
 CHECK(MatrixFramebuffer(&s,MATRIX_WIDTH,MATRIX_HEIGHT));CHECK(!MatrixFramebuffer(&s,MATRIX_WIDTH-1,MATRIX_HEIGHT));CHECK(!MatrixFramebuffer(&s,0,1));
 Info.PixelFormat=PixelBitMask;CHECK(!MatrixFramebuffer(&s,MATRIX_WIDTH,MATRIX_HEIGHT));Info.PixelFormat=PixelBlueGreenRedReserved8BitPerColor;
 TestMode.FrameBufferSize--;CHECK(!MatrixFramebuffer(&s,MATRIX_WIDTH,MATRIX_HEIGHT));TestMode.FrameBufferSize++;
 TestMode.FrameBufferBase++;CHECK(!MatrixFramebuffer(&s,MATRIX_WIDTH,MATRIX_HEIGHT));TestMode.FrameBufferBase--;
 UINT64 savedBase=TestMode.FrameBufferBase;TestMode.FrameBufferBase=~(UINT64)15;
 CHECK(!MatrixFramebuffer(&s,MATRIX_WIDTH,MATRIX_HEIGHT));TestMode.FrameBufferBase=savedBase;
 Info.PixelsPerScanLine--;CHECK(!MatrixFramebuffer(&s,MATRIX_WIDTH,MATRIX_HEIGHT));Info.PixelsPerScanLine++;
 CHECK(MatrixFramebuffer(&s,MATRIX_WIDTH,MATRIX_HEIGHT));
 for(UINTN i=0;i<MATRIX_PIXELS;i++)MatrixCurrent[i]=0xf800;
 HostVectorStores=0;MatrixWriteFramebuffer(&s,FALSE);CHECK(HostVectorStores==MATRIX_PIXELS/4);
 UINT32 *pixels=(UINT32*)(Ram+16);for(UINTN i=0;i<MATRIX_PIXELS;i++)CHECK(pixels[i]==0xff0000);
 for(UINTN i=0;i<MATRIX_PIXELS;i++)MatrixPrevious[i]=MatrixCurrent[i];
 HostVectorStores=0;MatrixWriteFramebuffer(&s,TRUE);CHECK(HostVectorStores==0);CHECK(pixels[0]==0xff0000);
 // A changed pixel rewrites exactly its 16-pixel group (four vector stores).
 MatrixCurrent[0]=0x07e0;HostVectorStores=0;MatrixWriteFramebuffer(&s,TRUE);
 CHECK(HostVectorStores==4);CHECK(pixels[0]==0x00ff00&&pixels[1]==0xff0000);
 End();
}
int main(void){
 Ram=aligned_alloc(16,MATRIX_PIXELS*sizeof(PIXEL)+32);CHECK(Ram!=NULL);FixtureInit();DecoderTests();LoadTests();LifecycleTests();FramebufferTests();free(Fixture);free(Ram);
 printf("PASS %u assertions: actual splash decoder, loader, RAM bounds and mocked lifecycle\n",Checks);return 0;
}
