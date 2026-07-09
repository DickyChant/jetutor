// compare.C -- overlay SHERPA vs Pythia feature distributions for ONE class and quantify the
// difference (KS distance + mean/width ratios). They should be SIMILAR but not identical
// (different shower/hadronization/ME). Writes a multi-pad PNG + a text summary of KS per feature.
//
//   root -l -b -q 'tools/compare.C("HToBB","/path/Sherpa","/path/Pythia","plots",200000)'
// Both dirs must be in the official JetClass layout (train_100M/CLASS_*.root). Works on the
// rebinned Sherpa output; for a quick self-test pass two Pythia ranges (KS ~ 0).
#include <vector>
#include "TChain.h"
#include "TH1F.h"
#include "TCanvas.h"
#include "TLegend.h"
#include "TStyle.h"
#include "TString.h"
#include <fstream>

static TH1F* draw(TChain* ch, const char* expr, const char* hname, int nb, double lo, double hi, Long64_t cap){
  TH1F* h=new TH1F(hname,hname,nb,lo,hi);
  ch->Draw(Form("%s>>%s",expr,hname),"","goff",cap);
  if(h->Integral()>0) h->Scale(1.0/h->Integral());
  return h;
}

void compare(TString cls, TString sherpaDir, TString pythiaDir, TString outdir="plots", Long64_t cap=200000, TString labA="SHERPA", TString labB="Pythia"){
  gStyle->SetOptStat(0);
  gSystem->mkdir(outdir, kTRUE);
  TChain* S=new TChain("tree"); S->Add(Form("%s/train_100M/%s_*.root", sherpaDir.Data(), cls.Data()));
  TChain* P=new TChain("tree"); P->Add(Form("%s/train_100M/%s_*.root", pythiaDir.Data(), cls.Data()));
  printf("[compare %s] SHERPA jets=%lld  Pythia jets=%lld  (cap=%lld)\n", cls.Data(), S->GetEntries(), P->GetEntries(), cap);

  struct Feat{ const char* name; const char* expr; int nb; double lo, hi; };
  std::vector<Feat> F = {
    {"jet_pt","jet_pt",60,450,1100}, {"jet_eta","jet_eta",50,-2.5,2.5},
    {"jet_energy","jet_energy",60,0,3000}, {"jet_sdmass","jet_sdmass",60,0,250},
    {"jet_nparticles","jet_nparticles",60,0,140},
    {"jet_tau1","jet_tau1",50,0,0.7},{"jet_tau2","jet_tau2",50,0,0.5},
    {"jet_tau3","jet_tau3",50,0,0.4},{"jet_tau4","jet_tau4",50,0,0.35},
    {"tau21","jet_tau2/jet_tau1",50,0,1.2},{"tau32","jet_tau3/jet_tau2",50,0,1.2},
    {"part_pt","sqrt(part_px*part_px+part_py*part_py)",60,0,200},
    {"part_deta","part_deta",60,-0.8,0.8},{"part_dphi","part_dphi",60,-0.8,0.8},
    {"part_energy","part_energy",60,0,300},{"part_charge","part_charge",5,-2,3},
    {"part_d0val","part_d0val",60,-1,1},{"part_dzval","part_dzval",60,-1,1},
    {"f_ChHad","part_isChargedHadron",2,0,2},{"f_NeutHad","part_isNeutralHadron",2,0,2},
    {"f_Photon","part_isPhoton",2,0,2},{"f_Electron","part_isElectron",2,0,2},{"f_Muon","part_isMuon",2,0,2},
  };
  int n=F.size(), nx=5, ny=(n+nx-1)/nx;
  TCanvas* c=new TCanvas("c","c",nx*340, ny*270); c->Divide(nx,ny);
  std::ofstream txt(Form("%s/compare_%s.txt", outdir.Data(), cls.Data()));
  txt<<"# "<<cls<<"  feature  KSdist  meanRatio(S/P)  rmsRatio(S/P)\n";
  for(int i=0;i<n;i++){
    c->cd(i+1);
    TH1F* hs=draw(S, F[i].expr, Form("s_%d",i), F[i].nb,F[i].lo,F[i].hi, cap);
    TH1F* hp=draw(P, F[i].expr, Form("p_%d",i), F[i].nb,F[i].lo,F[i].hi, cap);
    double ks=hs->KolmogorovTest(hp,"M");                 // KS distance (max CDF diff)
    double mr=(hp->GetMean()!=0)? hs->GetMean()/hp->GetMean():0;
    double rr=(hp->GetRMS()!=0)?  hs->GetRMS()/hp->GetRMS():0;
    hp->SetLineColor(kRed); hp->SetLineWidth(2); hs->SetLineColor(kBlack); hs->SetLineWidth(2);
    double mx=std::max(hs->GetMaximum(),hp->GetMaximum()); hp->SetMaximum(1.3*mx); hp->SetMinimum(0);
    hp->SetTitle(Form("%s  KS=%.3f", F[i].name, ks)); hp->Draw("hist"); hs->Draw("hist same");
    if(i==0){ TLegend* l=new TLegend(0.6,0.75,0.88,0.88); l->AddEntry(hs,labA,"l"); l->AddEntry(hp,labB,"l"); l->Draw(); }
    txt<<F[i].name<<"  "<<Form("%.4f  %.3f  %.3f",ks,mr,rr)<<"\n";
    printf("[compare %s] %-14s KS=%.4f  meanR=%.3f rmsR=%.3f\n", cls.Data(), F[i].name, ks, mr, rr);
  }
  txt.close();
  c->SaveAs(Form("%s/compare_%s.png", outdir.Data(), cls.Data()));
  printf("[compare %s] wrote %s/compare_%s.png + .txt\n", cls.Data(), outdir.Data(), cls.Data());
}
