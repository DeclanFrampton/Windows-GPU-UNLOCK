/* GPL-2.0-only. Enable IO/MEM only, then bounded read-only BAR0 observations. */
static BOOLEAN DecodeAttempted;
/* Exclude inaccessible 0x840100; bookend each batch with chip identity. */
static const UINT32 DecodeOffsets[]={0,0x118128,0x118234,0x110100,0x1fa824,0x1fa828,
  0x1fa7cc,0x1fa7c4,0x9a0148,0x823804,0x823814,0x823818,0x82381c,0x823820,
  0x1183a4,0x625f04,0x1fa7c8,0x1fa82c,0x1fa830,0x824148,0x8241e0,0};
static BOOLEAN DecodePost(const ED_STATE *before,const ED_STATE *after) {
  ED_STATE expected=*before;expected.Config[1]|=3U;expected.Attributes=0x300;
  return PfEqual(&expected,after,sizeof(expected));
}
typedef struct {UINT32 Values[22];EFI_STATUS Status[22];UINTN Attempted;} DECODE_READS;
static EFI_STATUS DecodeBatch(EFI_PCI_IO_PROTOCOL *io,DECODE_READS *out,EFI_PCI_IO_PROTOCOL_IO_MEM read) {
  EFI_STATUS result=EFI_SUCCESS;
  if(!read || io->Mem.Read!=read)return EFI_UNSUPPORTED;
  for(UINTN i=0;i<22;i++) {
    UINT32 value=MAX_UINT32;
    if(io->Mem.Read!=read)return EFI_NOT_READY;
    EFI_STATUS s=read(io,EfiPciIoWidthUint32,0,DecodeOffsets[i],1,&value);
    out->Values[i]=value;out->Status[i]=s;out->Attempted=i+1;
    if(io->Mem.Read!=read || s!=EFI_SUCCESS || value==MAX_UINT32 || (value&0xffff0000U)==0xbadf0000U ||
       ((!i || i==21) && value!=0x194000a1U)){result=s==EFI_SUCCESS?EFI_NOT_READY:s;break;}
  }
  return result;
}
static EFI_STATUS DecodeEmit(CAPTURE *c,const DECODE_READS *out,UINTN batch) {
  for(UINTN i=0;i<out->Attempted;i++) {
    Text(c,"ad104-register batch=0x");Hex(c,batch,2);Text(c," offset=0x");Hex(c,DecodeOffsets[i],8);
    Text(c," status=0x");Hex(c,out->Status[i],16);Text(c," value=0x");Hex(c,out->Values[i],8);End(c);
  }
  Text(c,"ad104-register batch=0x");Hex(c,batch,2);Text(c," attempted=0x");Hex(c,out->Attempted,2);End(c);
  return EdFlush(c);
}
static EFI_STATUS DecodeStep(CAPTURE *c,EFI_HANDLE gpu,EFI_PCI_IO_PROTOCOL *io,
                             const PF_PIN *pins,const ED_STATE *before) {
  EFI_SYSTEM_TABLE *t=c->Table;static ED_STATE pre,one,two,final;
  DECODE_READS a={0},b={0};EFI_PCI_IO_PROTOCOL_IO_MEM read=io->Mem.Read;
  if(DecodeAttempted || !ParentAttempted || !GuTextOutputDisabled)return EFI_ALREADY_STARTED;
  EFI_STATUS s=ParentCollect(c,gpu,io,pins,before->Drivers.Child,&pre);
  if(s!=EFI_SUCCESS || pre.Drivers.MatchedEdges!=2 || (pre.Config[1]&0xffff) || pre.Attributes ||
     (pre.Supported&0x300)!=0x300 || !PfEqual(before,&pre,sizeof(pre)) || !io->Attributes || !io->Mem.Read ||
     OwnerGone(t,pre.Drivers.Child)!=EFI_SUCCESS)return EFI_NOT_READY;
  Text(c,"ad104-display intent=enable-only-io-memory mask=0x300 no-bme-vga=1 register-reads-only=1 no-unlock=1\r\n");
  if(EdFlush(c)!=EFI_SUCCESS)return c->Io;
  s=ParentCollect(c,gpu,io,pins,before->Drivers.Child,&pre);
  if(s!=EFI_SUCCESS || !PfEqual(before,&pre,sizeof(pre)) || !io->Mem.Read ||
     OwnerGone(t,pre.Drivers.Child)!=EFI_SUCCESS)return EFI_NOT_READY;
  DecodeAttempted=TRUE;
  EFI_STATUS callback=io->Attributes(io,EfiPciIoAttributeOperationEnable,0x300,NULL);
  EFI_STATUS x=ParentCollect(c,gpu,io,pins,pre.Drivers.Child,&one);
  EFI_STATUS y=ParentCollect(c,gpu,io,pins,pre.Drivers.Child,&two);
  EFI_STATUS gone=OwnerGone(t,pre.Drivers.Child);
  EdStatus(c,"decode-return",callback);EdStatus(c,"decode-post",x);EdStatus(c,"decode-repeat",y);
  EdDescribe(c,&one,"decode-post");EdDescribe(c,&two,"decode-repeat");
  BOOLEAN good=callback==EFI_SUCCESS && x==EFI_SUCCESS && y==EFI_SUCCESS && gone==EFI_SUCCESS &&
    DecodePost(&pre,&one) && DecodePost(&pre,&two);
  if(EdFlush(c)!=EFI_SUCCESS)return c->Io;
  if(!good)return EFI_NOT_READY;
  /* Recheck after log services, before each batch of bounded MMIO reads. */
  x=ParentCollect(c,gpu,io,pins,pre.Drivers.Child,&one);
  if(x!=EFI_SUCCESS || !DecodePost(&pre,&one) || OwnerGone(t,pre.Drivers.Child)!=EFI_SUCCESS)return EFI_NOT_READY;
  x=DecodeBatch(io,&a,read);
  EFI_STATUS emit=DecodeEmit(c,&a,1);
  y=ParentCollect(c,gpu,io,pins,pre.Drivers.Child,&one);
  if(emit==EFI_SUCCESS && x==EFI_SUCCESS && y==EFI_SUCCESS && DecodePost(&pre,&one) && OwnerGone(t,pre.Drivers.Child)==EFI_SUCCESS)
    x=DecodeBatch(io,&b,read);
  else x=EFI_NOT_READY;
  emit=DecodeEmit(c,&b,2);
  y=ParentCollect(c,gpu,io,pins,pre.Drivers.Child,&two);
  good=emit==EFI_SUCCESS && a.Attempted==22 && b.Attempted==22 && x==EFI_SUCCESS && y==EFI_SUCCESS && DecodePost(&pre,&two) &&
    OwnerGone(t,pre.Drivers.Child)==EFI_SUCCESS && PfEqual(a.Values,b.Values,sizeof(a.Values));
  EdStatus(c,"register-capture",good?EFI_SUCCESS:EFI_NOT_READY);
  Text(c,"ad104-register cold-entry-admission=unreviewed transaction-executed=0\r\n");
  if(EdFlush(c)!=EFI_SUCCESS)return c->Io;
  if(!good)return EFI_NOT_READY;
  s=EdKey(t,'V',NULL);
  x=ParentCollect(c,gpu,io,pins,pre.Drivers.Child,&final);gone=OwnerGone(t,pre.Drivers.Child);
  EdStatus(c,"decode-input-after",s);EdStatus(c,"decode-final-post",x);EdDescribe(c,&final,"decode-final-post");
  if(s!=EFI_SUCCESS || x!=EFI_SUCCESS || gone!=EFI_SUCCESS || !DecodePost(&pre,&final))s=EFI_NOT_READY;
  EdStatus(c,"windows-eligible",s);if(EdFlush(c)!=EFI_SUCCESS)return c->Io;return s;
}
