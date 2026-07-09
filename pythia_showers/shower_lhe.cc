// shower_lhe: read a MadGraph LHE, shower+hadronise with a chosen Pythia 8.3 shower
// (simple / Vincia / Dire via PartonShowers:model in the .cmnd), write HepMC3 for Delphes.
//   shower_lhe <cmnd> <lhe_in.gz> <hepmc3_out> <nevents> <seed>
#include "Pythia8/Pythia.h"
#include "Pythia8Plugins/HepMC3.h"
#include <iostream>
using namespace Pythia8;
int main(int argc, char* argv[]) {
  if (argc < 6) { std::cerr << "usage: shower_lhe cmnd lhe_in hepmc_out nevents seed\n"; return 1; }
  std::string cmnd = argv[1], lhe = argv[2], out = argv[3];
  long nev = atol(argv[4]); int seed = atoi(argv[5]);
  Pythia pythia;
  pythia.readFile(cmnd);
  pythia.readString("Beams:frameType = 4");          // LHE input
  pythia.readString("Beams:LHEF = " + lhe);
  pythia.readString("Random:setSeed = on");
  pythia.readString("Random:seed = " + std::to_string(seed));
  if (!pythia.init()) { std::cerr << "ERROR: pythia.init() failed\n"; return 2; }
  // Write HepMC2-format ascii (DelphesHepMC2). Delphes' HepMC3 reader silently drops Pythia8's
  // HepMC3 flavour (0 events written); ascii2 is the proven JetClass/Herwig-chain format.
  Pythia8ToHepMC toHepMC(out, Pythia8ToHepMC::ascii2);
  long nshow = 0; int iAbort = 0;
  while (nshow < nev) {
    if (!pythia.next()) {
      if (pythia.info.atEndOfFile()) { std::cerr << "LHE exhausted at " << nshow << "\n"; break; }
      if (++iAbort > 200) { std::cerr << "ERROR: too many aborts\n"; break; }
      continue;
    }
    toHepMC.writeNextEvent(pythia);
    ++nshow;
  }
  pythia.stat();
  std::cerr << "DONE showered " << nshow << " events -> " << out << "\n";
  return 0;
}
