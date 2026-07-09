// verify.C -- branch/integrity check of the rebinned Sherpa dataset for ONE class:
//   * file counts per split (expect 100 train / 20 test / 5 val)
//   * every file has exactly per_file (100k) entries
//   * 41 branches present (names match official)
//   * label one-hot: exactly one label_*==1, and it is the expected class
//   * particle-type one-hot: every particle has exactly one of part_isX set
// Prints VERIFY lines; the sbatch wrapper greps for "FAIL".
//
//   root -l -b -q 'tools/verify.C("HToBB","/path/Sherpa")'
#include "TChain.h"
#include "TFile.h"
#include "TSystemDirectory.h"
#include "TTreeReader.h"
#include "TTreeReaderValue.h"
#include "TTreeReaderArray.h"
#include <map>

void verify(TString cls, TString root, Long64_t per_file=100000){
  std::map<TString,int> LAB={{"ZJetsToNuNu",0},{"HToBB",1},{"HToCC",2},{"HToGG",3},{"HToWW4Q",4},
    {"HToWW2Q1L",5},{"ZToQQ",6},{"WToQQ",7},{"TTBar",8},{"TTBarLep",9}};
  const char* LABN[10]={"label_QCD","label_Hbb","label_Hcc","label_Hgg","label_H4q",
                        "label_Hqql","label_Zqq","label_Wqq","label_Tbqq","label_Tbl"};
  int want=LAB[cls]; int fails=0;
  struct Split{const char* d;int n;}; Split SP[3]={{"train_100M",100},{"test_20M",20},{"val_5M",5}};
  for(auto&sp:SP){
    int have=0; bool badN=false;
    for(int i=0;i<sp.n+5;i++){
      TString fn=Form("%s/%s/%s_%03d.root",root.Data(),sp.d,cls.Data(),
                      (TString(sp.d)=="test_20M"?100:TString(sp.d)=="val_5M"?120:0)+i);
      if(gSystem->AccessPathName(fn)) continue;
      have++; TFile f(fn); TTree*t=(TTree*)f.Get("tree");
      if(!t){ printf("VERIFY FAIL %s %s: no tree in %s\n",cls.Data(),sp.d,fn.Data()); fails++; continue; }
      if(t->GetEntries()!=per_file){ printf("VERIFY FAIL %s: %s has %lld entries (!=%lld)\n",cls.Data(),fn.Data(),t->GetEntries(),per_file); badN=true; }
      if(t->GetNbranches()!=41){ printf("VERIFY FAIL %s: %s has %d branches (!=41)\n",cls.Data(),fn.Data(),t->GetNbranches()); fails++; }
    }
    if(have!=sp.n){ printf("VERIFY FAIL %s %s: %d files (!=%d)\n",cls.Data(),sp.d,have,sp.n); fails++; }
    if(badN) fails++;
    printf("VERIFY %s %s: %d files\n",cls.Data(),sp.d,have);
  }
  // content checks on the first train file
  TString f0=Form("%s/train_100M/%s_000.root",root.Data(),cls.Data());
  if(!gSystem->AccessPathName(f0)){
    TFile f(f0); TTree*t=(TTree*)f.Get("tree"); TTreeReader R(t);
    std::vector<TTreeReaderValue<Int_t>*> lab; for(int i=0;i<10;i++) lab.push_back(new TTreeReaderValue<Int_t>(R,LABN[i]));
    TTreeReaderArray<int> isch(R,"part_isChargedHadron"),isnh(R,"part_isNeutralHadron"),
      isph(R,"part_isPhoton"),isel(R,"part_isElectron"),ismu(R,"part_isMuon");
    Long64_t k=0,labbad=0,onehotbad=0;
    while(R.Next() && k<20000){
      int s=0,which=-1; for(int i=0;i<10;i++){ int v=**lab[i]; s+=v; if(v) which=i; }
      if(s!=1||which!=want) labbad++;
      for(size_t j=0;j<isch.GetSize();j++){ int sum=isch[j]+isnh[j]+isph[j]+isel[j]+ismu[j]; if(sum!=1){onehotbad++;break;} }
      k++;
    }
    if(labbad){ printf("VERIFY FAIL %s: %lld/%lld jets with wrong label one-hot\n",cls.Data(),labbad,k); fails++; }
    else printf("VERIFY %s: label one-hot OK (%lld jets, all label_%s)\n",cls.Data(),k,LABN[want]);
    if(onehotbad){ printf("VERIFY FAIL %s: %lld jets with bad particle-type one-hot\n",cls.Data(),onehotbad); fails++; }
    else printf("VERIFY %s: particle-type one-hot OK\n",cls.Data());
  }
  printf("VERIFY %s: %s (fails=%d)\n",cls.Data(),fails?"PROBLEMS":"ALL GOOD",fails);
}
