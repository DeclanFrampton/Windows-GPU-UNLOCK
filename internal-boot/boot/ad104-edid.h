/* GPL-2.0-only. One attended EDID disconnect; no PCI owner release or unlock. */
typedef struct {
  PF_STATE Drivers;
  UINT32 Config[64];
  EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR Bar;
  UINT64 BarSupport,Attributes,Supported;
  EFI_HANDLE InputHandle,OutputHandle,ErrorHandle;
  EFI_SIMPLE_TEXT_INPUT_PROTOCOL *Input;
  EFI_INPUT_RESET Reset;
  EFI_INPUT_READ_KEY Read;
  EFI_EVENT Wait;
  VOID *Output,*Error;
} ED_STATE;
static BOOLEAN EdAttempted;

static EFI_STATUS EdFlush(CAPTURE *c) {
  if(c->Io!=EFI_SUCCESS)return c->Io;
  if(c->Used) {
    UINTN n=c->Used;c->Io=c->File->Write(c->File,&n,c->Buffer);
    if(c->Io==EFI_SUCCESS && n!=c->Used)c->Io=EFI_DEVICE_ERROR;
    c->Used=0;
  }
  if(c->Io==EFI_SUCCESS)c->Io=c->File->Flush(c->File);
  return c->Io;
}
static VOID EdStatus(CAPTURE *c,const char *stage,EFI_STATUS s) {
  Text(c,"ad104-edid stage=");Text(c,stage);Text(c," status=0x");Hex(c,s,16);End(c);
}
static VOID EdDescribe(CAPTURE *c,const ED_STATE *s,const char *stage) {
  Text(c,"ad104-edid-state stage=");Text(c,stage);
  Text(c," edges=0x");Hex(c,s->Drivers.MatchedEdges,2);
  Text(c," shared-byte=0x");Hex(c,s->Drivers.SharedFlag,2);
  Text(c," pointer-count1=0x");Hex(c,s->Drivers.PointerCounts[0],16);
  Text(c," pointer-count2=0x");Hex(c,s->Drivers.PointerCounts[1],16);
  Text(c," attributes=0x");Hex(c,s->Attributes,16);
  Text(c," supported=0x");Hex(c,s->Supported,16);End(c);
  Text(c,"ad104-edid-cfg stage=");Text(c,stage);Text(c," dwords=");
  for(UINTN i=0;i<64;i++){Hex(c,s->Config[i],8);Text(c," ");}End(c);
}
static EFI_STATUS EdCollect(EFI_SYSTEM_TABLE *t,EFI_HANDLE gpu,EFI_PCI_IO_PROTOCOL *io,
                            const PF_PIN *pins,BOOLEAN post,ED_STATE *out) {
  UINT8 *z=(VOID *)out;for(UINTN i=0;i<sizeof(*out);i++)z[i]=0;
  EFI_STATUS first=PfDrivers(t,pins,&out->Drivers);
  if(first==EFI_SUCCESS)first=PfGraphForState(t,gpu,&out->Drivers,post);
  /* Continue independent observations even when the graph is unexpected. */
  EFI_PCI_IO_PROTOCOL *fresh=NULL;UINTN loc[4]={0};
  EFI_STATUS s=t->BootServices->HandleProtocol(gpu,&PciGuidL,(VOID **)&fresh);
  if(s!=EFI_SUCCESS || fresh!=io)return first!=EFI_SUCCESS?first:EFI_NOT_READY;
  s=io->Pci.Read?io->Pci.Read(io,EfiPciIoWidthUint32,0,64,out->Config):EFI_UNSUPPORTED;
  if(s!=EFI_SUCCESS && first==EFI_SUCCESS)first=s;
  s=io->GetLocation?io->GetLocation(io,&loc[0],&loc[1],&loc[2],&loc[3]):EFI_UNSUPPORTED;
  if((s!=EFI_SUCCESS || loc[0] || loc[1]!=11 || loc[2] || loc[3]) && first==EFI_SUCCESS)first=EFI_NOT_READY;
  VOID *raw=NULL;
  s=io->GetBarAttributes?io->GetBarAttributes(io,0,&out->BarSupport,&raw):EFI_UNSUPPORTED;
  if(s==EFI_SUCCESS && raw) {
    EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR *d=raw;
    if(d->Desc==ACPI_ADDRESS_SPACE_DESCRIPTOR && d->Len==sizeof(*d)-3) {
      UINT8 sum=0;const UINT8 *end=(const UINT8 *)(d+1);
      for(UINTN i=0;i<sizeof(*d)+2;i++)sum=(UINT8)(sum+((UINT8 *)raw)[i]);
      if(end[0]==ACPI_END_TAG_DESCRIPTOR && (!end[1] || !sum))out->Bar=*d;
      else if(first==EFI_SUCCESS)first=EFI_UNSUPPORTED;
    } else if(first==EFI_SUCCESS)first=EFI_UNSUPPORTED;
  } else if(first==EFI_SUCCESS)first=EFI_NOT_READY;
  if(raw && t->BootServices->FreePool(raw)!=EFI_SUCCESS && first==EFI_SUCCESS)first=EFI_DEVICE_ERROR;
  s=io->Attributes?io->Attributes(io,EfiPciIoAttributeOperationGet,0,&out->Attributes):EFI_UNSUPPORTED;
  if(s!=EFI_SUCCESS && first==EFI_SUCCESS)first=s;
  s=io->Attributes?io->Attributes(io,EfiPciIoAttributeOperationSupported,0,&out->Supported):EFI_UNSUPPORTED;
  if(s!=EFI_SUCCESS && first==EFI_SUCCESS)first=s;
  out->InputHandle=t->ConsoleInHandle;out->OutputHandle=t->ConsoleOutHandle;out->ErrorHandle=t->StandardErrorHandle;
  out->Input=t->ConIn;out->Output=t->ConOut;out->Error=t->StdErr;
  if(t->ConIn){out->Reset=t->ConIn->Reset;out->Read=t->ConIn->ReadKeyStroke;out->Wait=t->ConIn->WaitForKey;}
  if(!out->Input || !out->Reset || !out->Read || !out->Wait || !out->Output || !out->Error)
    if(first==EFI_SUCCESS)first=EFI_UNSUPPORTED;
  return first;
}
static BOOLEAN EdInitial(const ED_STATE *s) {
  return s->Config[0]==0x278210deU && s->Config[11]==0x51321462U && s->Config[2]==0x030000a1U &&
    (s->Config[1]&0xffffU)==7 && s->Config[4]==0xfb000000U && s->Attributes==0x718 && s->Supported==0x1b77b &&
    !s->BarSupport && !s->Bar.ResType && s->Bar.AddrSpaceGranularity==32 &&
    s->Bar.AddrRangeMin==0xfb000000 && s->Bar.AddrRangeMax==0xfbffffff &&
    s->Bar.AddrLen==0x1000000 && !s->Bar.AddrTranslationOffset &&
    s->Drivers.MatchedEdges==8 && s->Drivers.SharedFlag==1 &&
    s->Drivers.PointerCounts[0]==1 && s->Drivers.PointerCounts[1]==1;
}
static BOOLEAN EdPost(const ED_STATE *before,const ED_STATE *after) {
  ED_STATE expected=*before;expected.Drivers.MatchedEdges=7;expected.Drivers.SharedFlag=0;
  return PfEqual(&expected,after,sizeof(expected));
}
static EFI_STATUS EdKey(EFI_SYSTEM_TABLE *t,CHAR16 wanted,const CHAR16 *prompt) {
  if(!t->ConIn || !t->ConIn->ReadKeyStroke || !t->ConOut || !t->ConOut->OutputString || !t->BootServices->Stall)
    return EFI_UNSUPPORTED;
  EFI_INPUT_KEY k;EFI_STATUS s=EFI_SUCCESS;
  /* Bounded drain prevents a held/queued key from authorizing a later stage. */
  for(UINTN i=0;i<32;i++) {
    s=t->ConIn->ReadKeyStroke(t->ConIn,&k);
    if(s==EFI_NOT_READY)break;
    if(s!=EFI_SUCCESS)return s;
  }
  if(s!=EFI_NOT_READY)return EFI_NOT_READY;
  s=t->ConOut->OutputString(t->ConOut,(CHAR16 *)prompt);if(s!=EFI_SUCCESS)return s;
  for(UINTN i=0;i<600;i++) {
    s=t->ConIn->ReadKeyStroke(t->ConIn,&k);
    if(s==EFI_SUCCESS)return !k.ScanCode && k.UnicodeChar==wanted?EFI_SUCCESS:EFI_ABORTED;
    if(s!=EFI_NOT_READY)return s;
    s=t->BootServices->Stall(100000);if(s!=EFI_SUCCESS)return s;
  }
  return EFI_TIMEOUT;
}
static EFI_STATUS EdRun(CAPTURE *c,EFI_HANDLE gpu,EFI_PCI_IO_PROTOCOL *io,const PF_PIN *pins) {
  EFI_SYSTEM_TABLE *t=c->Table;static ED_STATE a,b,p,q;
  if(EdAttempted)return EFI_ALREADY_STARTED;
  if(!io || !io->Pci.Read || !io->GetLocation || !io->GetBarAttributes || !io->Attributes ||
     !t->BootServices->DisconnectController)return EFI_UNSUPPORTED;
  EFI_STATUS s=EdCollect(t,gpu,io,pins,FALSE,&a);
  EdDescribe(c,&a,"initial");EdStatus(c,"initial",s);
  if(s!=EFI_SUCCESS || !EdInitial(&a))return EFI_NOT_READY;
  s=EdKey(t,'E',L"EDID TEST: display/input may be lost; manual power-off may be needed.\r\nPress uppercase E within 60 seconds to attempt ONE EDID disconnect. Any other key cancels.\r\n");
  EdStatus(c,"input-before",s);if(EdFlush(c)!=EFI_SUCCESS)return c->Io;
  if(s!=EFI_SUCCESS)return s;
  s=EdCollect(t,gpu,io,pins,FALSE,&b);
  if(s!=EFI_SUCCESS || !PfEqual(&a,&b,sizeof(a)))return EFI_NOT_READY;
  Text(c,"ad104-edid intent=one-disconnect target=gop-child agent=img08 no-retry=1 no-unlock=1\r\n");
  if(EdFlush(c)!=EFI_SUCCESS)return c->Io;
  /* Recollect after logging to detect intervening changes. No further I/O
   * between this agreeing collection and the single callback invocation. */
  s=EdCollect(t,gpu,io,pins,FALSE,&b);
  if(s!=EFI_SUCCESS || !PfEqual(&a,&b,sizeof(a)))return EFI_NOT_READY;
  EdAttempted=TRUE;
  EFI_STATUS callback=t->BootServices->DisconnectController(a.Drivers.Child,a.Drivers.Agent[0],NULL);
  EFI_STATUS post=EdCollect(t,gpu,io,pins,TRUE,&p);
  EFI_STATUS repeat=EdCollect(t,gpu,io,pins,TRUE,&q);
  EdStatus(c,"disconnect-return",callback);EdStatus(c,"post",post);EdStatus(c,"post-repeat",repeat);
  EdDescribe(c,&p,"post");EdDescribe(c,&q,"post-repeat");
  BOOLEAN good=callback==EFI_SUCCESS && post==EFI_SUCCESS && repeat==EFI_SUCCESS &&
    EdPost(&a,&p) && EdPost(&a,&q);
  if(EdFlush(c)!=EFI_SUCCESS)return c->Io;
  if(!good)return EFI_NOT_READY;
  s=EdKey(t,'V',L"EDID callback returned and state checks passed.\r\nPress uppercase V within 60 seconds to verify input and continue to Windows. Any other key stops.\r\n");
  EdStatus(c,"input-after",s);
  /* Input callbacks may themselves change shared state: check again. */
  post=EdCollect(t,gpu,io,pins,TRUE,&p);EdStatus(c,"final-post",post);EdDescribe(c,&p,"final-post");
  if(s!=EFI_SUCCESS || post!=EFI_SUCCESS || !EdPost(&a,&p))s=EFI_NOT_READY;
  EdStatus(c,"windows-eligible",s);
  if(EdFlush(c)!=EFI_SUCCESS)return c->Io;
  return s;
}
