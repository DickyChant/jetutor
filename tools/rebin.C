// rebin.C -- convert the hqu SHERPA ntuples for ONE class into the OFFICIAL JetClass format:
//   * exactly PER_FILE (100k) jets per output file
//   * official 41-branch schema (one-hot label_*, one-hot part_isX, scalar aux_genpart_*,
//     aux_truth_match); drops gen_match / part_pid / part_pt (not in official)
//   * official file split + naming: CLASS_000..099 -> train_100M, 100..119 -> test_20M,
//     120..124 -> val_5M  (so it drops in as a Sherpa/ sibling of Pythia/)
//
// One pass with TTreeReader (handles file transitions cleanly). ROOT 6.38 exits nonzero even
// on success -> the sbatch wrapper judges success by the produced files, not root's exit.
//
//   root -l -b -q 'tools/rebin.C("HToBB","data","/pscratch/.../JetClass/Sherpa")'
#include <map>
#include <vector>
#include "TChain.h"
#include "TTree.h"
#include "TFile.h"
#include "TTreeReader.h"
#include "TTreeReaderValue.h"
#include "TTreeReaderArray.h"
#include "TSystem.h"

void rebin(TString cls, TString indir, TString outdir,
           int n_train=100, int n_test=20, int n_val=5, Long64_t per_file=100000,
           TString pat="_*_b*",      // input glob: Sherpa "_*_b*", Herwig "_*"
           int minparts=0,           // drop jets with jet_nparticles < minparts (e.g. 2 -> no single-particle jets)
           float ptmax=0,            // drop jets with jet_pt > ptmax (e.g. 1000 to match JetClass cap); 0 = off
           int genmatch=0) {         // keep ONLY jets with gen_match==genmatch (e.g. 46 for unified HToWW->2q1l); 0 = off
  // class -> index in the official one-hot label vector
  std::map<TString,int> LAB = {
    {"ZJetsToNuNu",0},{"HToBB",1},{"HToCC",2},{"HToGG",3},{"HToWW4Q",4},
    {"HToWW2Q1L",5},{"ZToQQ",6},{"WToQQ",7},{"TTBar",8},{"TTBarLep",9}};
  const char* LABNAME[10]={"label_QCD","label_Hbb","label_Hcc","label_Hgg","label_H4q",
                           "label_Hqql","label_Zqq","label_Wqq","label_Tbqq","label_Tbl"};
  if (LAB.find(cls)==LAB.end()){ printf("unknown class %s\n",cls.Data()); return; }
  int labidx = LAB[cls];
  int n_total = n_train + n_test + n_val;

  TChain ch("tree");
  int nf = ch.Add(Form("%s/%s/%s%s.root", indir.Data(), cls.Data(), cls.Data(), pat.Data()));
  Long64_t N = ch.GetEntries();
  printf("[rebin %s] %d input files, %lld jets -> %d files x %lld = %lld jets needed\n",
         cls.Data(), nf, N, n_total, per_file, (Long64_t)n_total*per_file);
  if (N < (Long64_t)n_total*per_file)
    printf("[rebin %s] WARNING: only %lld jets (< %lld) -> will write fewer than %d files\n",
           cls.Data(), N, (Long64_t)n_total*per_file, n_total);

  TTreeReader R(&ch);
  // input part vectors
  const char* PK[11]={"part_px","part_py","part_pz","part_energy","part_deta","part_dphi",
                      "part_d0val","part_d0err","part_dzval","part_dzerr","part_charge"};
  std::vector<TTreeReaderArray<float>*> in_pk;
  for(int i=0;i<11;i++) in_pk.push_back(new TTreeReaderArray<float>(R, PK[i]));
  TTreeReaderArray<float> in_pid(R,"part_pid"), in_charge(R,"part_charge");
  // input jet scalars
  const char* JK[10]={"jet_pt","jet_eta","jet_phi","jet_energy","jet_nparticles",
                      "jet_sdmass","jet_tau1","jet_tau2","jet_tau3","jet_tau4"};
  std::vector<TTreeReaderValue<float>*> in_jk;
  for(int i=0;i<10;i++) in_jk.push_back(new TTreeReaderValue<float>(R, JK[i]));
  TTreeReaderValue<float> in_geta(R,"genpart_eta"), in_gphi(R,"genpart_phi"),
                          in_gpid(R,"genpart_pid"), in_gpt(R,"genpart_pt"), in_sig(R,"is_signal");
  TTreeReaderValue<float> in_gm(R,"gen_match");   // hqu gen-match code (float); used by genmatch filter

  // output buffers
  std::vector<float> o_pk[11];                 // copied kinematics
  std::vector<int>   o_is[5];                  // isChargedHadron,isNeutralHadron,isPhoton,isElectron,isMuon
  int    o_label[10];
  float  o_jet[10], o_aux[4], o_match;

  TFile* fout=nullptr; TTree* tout=nullptr;
  Long64_t in_file=0; int chunk=-1;
  auto open_chunk=[&](int c){
    TString sub = (c<n_train)? "train_100M" : (c<n_train+n_test)? "test_20M" : "val_5M";
    TString dir = outdir + "/" + sub; gSystem->mkdir(dir, kTRUE);
    TString fn = Form("%s/%s_%03d.root", dir.Data(), cls.Data(), c);
    fout = new TFile(fn,"RECREATE"); tout = new TTree("tree","tree");
    for(int i=0;i<11;i++) tout->Branch(PK[i], &o_pk[i]);
    const char* ISN[5]={"part_isChargedHadron","part_isNeutralHadron","part_isPhoton","part_isElectron","part_isMuon"};
    for(int i=0;i<5;i++) tout->Branch(ISN[i], &o_is[i]);
    for(int i=0;i<10;i++) tout->Branch(LABNAME[i], &o_label[i], Form("%s/I",LABNAME[i]));
    for(int i=0;i<10;i++) tout->Branch(JK[i], &o_jet[i], Form("%s/F",JK[i]));
    const char* AUX[4]={"aux_genpart_eta","aux_genpart_phi","aux_genpart_pid","aux_genpart_pt"};
    for(int i=0;i<4;i++) tout->Branch(AUX[i], &o_aux[i], Form("%s/F",AUX[i]));
    tout->Branch("aux_truth_match", &o_match, "aux_truth_match/F");
  };
  auto close_chunk=[&](){ if(fout){ fout->cd(); tout->Write(); fout->Close(); delete fout; fout=nullptr; tout=nullptr; } };

  Long64_t written=0;
  Long64_t skip_np=0, skip_pt=0, skip_gm=0;
  while (R.Next()) {
    // quality filters (backfilled from the surplus since we stop at exactly n_total files)
    if (genmatch>0 && (int)(*in_gm + 0.5) != genmatch){ skip_gm++; continue; }  // wrong gen-match (mixed input)
    if (minparts>0 && *(*in_jk[4]) <  minparts){ skip_np++; continue; }   // jet_nparticles
    if (ptmax  >0 && *(*in_jk[0]) >  ptmax)    { skip_pt++; continue; }   // jet_pt
    int c = written / per_file;
    if (c >= n_total) break;                   // enough -> stop (exactly n_total files)
    if (c != chunk){ close_chunk(); chunk=c; open_chunk(c); }

    // copy kinematics
    for(int i=0;i<11;i++){ o_pk[i].assign(in_pk[i]->begin(), in_pk[i]->end()); }
    // particle-type one-hot from pid+charge (official logic, ntuple/makeNtuples.C:244-248)
    size_t np = in_pid.GetSize();
    for(int i=0;i<5;i++) o_is[i].clear();
    for(size_t j=0;j<np;j++){
      int pid=(int)in_pid[j]; float q=in_charge[j];
      bool isE=(pid==11||pid==-11), isMu=(pid==13||pid==-13), isPh=(pid==22);
      o_is[0].push_back( (q!=0 && !(isE||isMu)) ? 1:0 );  // ChargedHadron
      o_is[1].push_back( (q==0 && !isPh)        ? 1:0 );  // NeutralHadron
      o_is[2].push_back( isPh ?1:0 );
      o_is[3].push_back( isE  ?1:0 );
      o_is[4].push_back( isMu ?1:0 );
    }
    for(int i=0;i<10;i++) o_label[i]= (i==labidx)?1:0;
    for(int i=0;i<10;i++) o_jet[i]= *(*in_jk[i]);
    o_aux[0]=*in_geta; o_aux[1]=*in_gphi; o_aux[2]=*in_gpid; o_aux[3]=*in_gpt;
    o_match=*in_sig;
    tout->Fill(); written++;
    if (written % 500000 == 0) printf("[rebin %s] %lld jets -> file %d\n", cls.Data(), written, chunk);
  }
  close_chunk();
  int files = (written + per_file - 1)/per_file;
  printf("[rebin %s] DONE: wrote %lld jets in %d files (full=%lld); skipped %lld (nparts<%d) + %lld (pt>%g) + %lld (gen_match!=%d)\n",
         cls.Data(), written, files, written/per_file, skip_np, minparts, skip_pt, ptmax, skip_gm, genmatch);
}
