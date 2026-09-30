// #include <iostream>
// #include <unordered_set>
// #include <utility>
// #include "TClonesArray.h"
// #include "Math/LorentzVector.h"
// #include "classes/DelphesClasses.h"
// #include "external/ExRootAnalysis/ExRootTreeReader.h"

#ifdef __CLING__
R__LOAD_LIBRARY(libDelphes)
#include "classes/DelphesClasses.h"
#include "external/ExRootAnalysis/ExRootTreeReader.h"
#include <bitset>
#include <limits>
#else
class ExRootTreeReader;
#endif

double deltaPhi(double phi1, double phi2) { return TVector2::Phi_mpi_pi(phi1 - phi2); }

double deltaR(double eta1, double phi1, double eta2, double phi2) {
  double deta = eta1 - eta2;
  double dphi = deltaPhi(phi1, phi2);
  return std::hypot(deta, dphi);
}

template <class T1, class T2>
double deltaR(const T1 &a, const T2 &b) {
  return deltaR(a->Eta, a->Phi, b->Eta, b->Phi);
}

namespace ParticleID {
  enum PdgId {
    p_unknown,
    p_d,
    p_u,
    p_s,
    p_c,
    p_b,
    p_t,
    p_bprime,
    p_tprime,
    p_eminus = 11,
    p_nu_e,
    p_muminus,
    p_nu_mu,
    p_tauminus,
    p_nu_tau,
    p_tauprimeminus,
    p_nu_tauprime,
    p_g = 21,
    p_gamma,
    p_Z0,
    p_Wplus,
    p_h0,
    p_Zprime0 = 32,
    p_Zpprime0,
    p_Wprimeplus,
    p_H0,
    p_A0,
    p_Hplus,
    p_G = 39,
    p_R0 = 41,
    p_H30 = 45,
    p_A20 = 46,
    p_LQ,
    p_cluster = 91,
    p_string,
    p_pi0 = 111,
    p_rho0 = 113,
    p_klong = 130,
    p_piplus = 211,
    p_rhoplus = 213,
    p_eta = 221,
    p_omega = 223,
    p_kshort = 310,
    p_k0,
    p_kstar0 = 313,
    p_kplus = 321,
    p_kstarplus = 323,
    p_phi = 333,
    p_dplus = 411,
    p_d0 = 421,
    p_dsplus = 431,
    p_b0 = 511,
    p_bplus = 521,
    p_bs0 = 531,
    p_bcplus = 541,
    p_neutron = 2112,
    p_proton = 2212,
    p_sigmaminus = 3112,
    p_lambda0 = 3122,
    p_sigma0 = 3212,
    p_sigmaplus = 3222,
    p_ximinus = 3312,
    p_xi0 = 3322,
    p_omegaminus = 3334,
    p_sigmac0 = 4112,
    p_lambdacplus = 4122,
    p_xic0 = 4132,
    p_sigmacplus = 4212,
    p_sigmacpp = 4222,
    p_xicplus = 4232,
    p_omegac0 = 4332,
    p_sigmabminus = 5112,
    p_lambdab0 = 5122,
    p_xibminus = 5132,
    p_sigmab0 = 5212,
    p_sigmabplus = 5222,
    p_xib0 = 5232,
    p_omegabminus = 5332,
  };
}

class FatJetMatching {
public:
  enum EventType {
    QCD = 0,
    Higgs,
    Top,
    W,
    Z,
  };

  enum FatJetLabel {
    Invalid = 0,
    Top_all = 10,
    Top_bcq,
    Top_bqq,
    Top_bc,
    Top_bq,
    Top_ben,
    Top_bmn,
    W_all = 20,
    W_cq,
    W_qq,
    Z_all = 30,
    Z_bb,
    Z_cc,
    Z_qq,
    H_all = 40,
    H_bb,
    H_cc,
    H_qq,
    H_gg,
    H_ww4q,
    H_ww2q1l,
    QCD_all = 50,
    QCD_bb,
    QCD_cc,
    QCD_b,
    QCD_c,
    QCD_others
  };

public:
  FatJetMatching() {}
  FatJetMatching(double jetR) : jetR_(jetR) {}

  virtual ~FatJetMatching() {}

  EventType event_type() const { return event_type_; }

  std::pair<FatJetLabel, const GenParticle *> getLabel(const Jet *jet, const TClonesArray *branchParticle) {
    genParticles_.clear();
    for (Int_t i = 0; i < branchParticle->GetEntriesFast(); ++i) {
      genParticles_.push_back((GenParticle *)branchParticle->At(i));
    }
    processed_.clear();
    event_type_ = EventType::QCD;

    if (debug_) {
      std::cout << "\n=======\nJet (energy, pT, eta, phi) = " << jet->P4().Energy() << ", " << jet->PT << ", "
                << jet->Eta << ", " << jet->Phi << std::endl
                << std::endl;
      printGenInfoHeader();
      for (unsigned ipart = 0; ipart < genParticles_.size(); ++ipart) {
        printGenParticleInfo(genParticles_[ipart], ipart);
      }
    }

    for (const auto *gp : genParticles_) {
      if (processed_.count(gp))
        continue;
      processed_.insert(gp);

      auto pdgid = std::abs(gp->PID);
      if (pdgid == ParticleID::p_t) {
        auto result = top_label(jet, gp);
        if (result.first != FatJetLabel::Invalid) {
          return result;
        }
      } else if (pdgid == ParticleID::p_h0) {
        auto result = higgs_label(jet, gp);
        if (result.first != FatJetLabel::Invalid) {
          return result;
        }
      } else if (pdgid == ParticleID::p_Wplus) {
        auto result = w_label(jet, gp);
        if (result.first != FatJetLabel::Invalid) {
          return result;
        }
      } else if (pdgid == ParticleID::p_Z0) {
        auto result = z_label(jet, gp);
        if (result.first != FatJetLabel::Invalid) {
          return result;
        }
      }
    }

    if (genParticles_.size() != processed_.size())
      throw std::logic_error("[FatJetMatching] Not all genParticles are processed!");

    return std::make_pair(FatJetLabel::QCD_all, nullptr);
  }

private:
  std::pair<FatJetLabel, const GenParticle *> top_label(const Jet *jet, const GenParticle *parton) {
    // top
    auto top = getFinal(parton);
    // find the W and test if it's hadronic
    const GenParticle *w_from_top = nullptr, *b_from_top = nullptr;
    for (const auto *dau : getDaughters(top)) {
      if (std::abs(dau->PID) == ParticleID::p_Wplus) {
        w_from_top = getFinal(dau);
      } else if (std::abs(dau->PID) <= ParticleID::p_b) {
        // ! use <= p_b ! -- can also have charms etc.
        b_from_top = dau;
      }
    }
    if (!w_from_top || !b_from_top)
      throw std::logic_error("[FatJetMatching::top_label] Cannot find b or W from top decay!");

    if (isHadronic(w_from_top)) {
      if (event_type_ == EventType::QCD) {
        event_type_ = EventType::Top;
      }
      if (debug_) {
        using namespace std;
        cout << "jet: (" << jet->PT << ", " << jet->Eta << ", " << jet->Phi << ", " << jet->P4().Energy() << ")"
             << endl;
        cout << "top: ";
        printGenParticleInfo(top, -1);
        cout << "b:   ";
        printGenParticleInfo(b_from_top, -1);
        cout << "W:   ";
        printGenParticleInfo(w_from_top, -1);
      }

      auto wdaus = getDaughterQuarks(w_from_top);
      if (wdaus.size() < 2)
        throw std::logic_error("[FatJetMatching::top_label] W decay has less than 2 quarks!");
      //    if (wdaus.size() >= 2)
      {
        double dr_b = deltaR(jet, b_from_top);
        double dr_q1 = deltaR(jet, wdaus.at(0));
        double dr_q2 = deltaR(jet, wdaus.at(1));
        if (dr_q1 > dr_q2) {
          // swap q1 and q2 so that dr_q1<=dr_q2
          std::swap(dr_q1, dr_q2);
          std::swap(wdaus.at(0), wdaus.at(1));
        }

        if (debug_) {
          using namespace std;
          cout << "deltaR(jet, b)     : " << dr_b << endl;
          cout << "deltaR(jet, q1)    : " << dr_q1 << endl;
          cout << "deltaR(jet, q2)    : " << dr_q2 << endl;
        }

        if (dr_b < jetR_) {
          auto pdgid_q1 = std::abs(wdaus.at(0)->PID);
          auto pdgid_q2 = std::abs(wdaus.at(1)->PID);
          if (debug_) {
            using namespace std;
            cout << "pdgid(q1)        : " << pdgid_q1 << endl;
            cout << "pdgid(q2)        : " << pdgid_q2 << endl;
          }

          if (dr_q1 < jetR_ && dr_q2 < jetR_) {
            if (pdgid_q1 >= ParticleID::p_c || pdgid_q2 >= ParticleID::p_c) {
              return std::make_pair(FatJetLabel::Top_bcq, top);
            } else {
              return std::make_pair(FatJetLabel::Top_bqq, top);
            }
          } else if (dr_q1 < jetR_ && dr_q2 >= jetR_) {
            if (pdgid_q1 >= ParticleID::p_c) {
              return std::make_pair(FatJetLabel::Top_bc, top);
            } else {
              return std::make_pair(FatJetLabel::Top_bq, top);
            }
          }
        } else {
          // test for W if dr(b, jet) > jetR_
          return w_label(jet, w_from_top);
        }
      }
    } else {
      // leptonic W
      if (event_type_ == EventType::QCD) {
        event_type_ = EventType::Top;
      }
      if (debug_) {
        using namespace std;
        cout << "jet: (" << jet->PT << ", " << jet->Eta << ", " << jet->Phi << ", " << jet->P4().Energy() << ")"
             << endl;
        cout << "top: ";
        printGenParticleInfo(top, -1);
        cout << "b:   ";
        printGenParticleInfo(b_from_top, -1);
        cout << "W:   ";
        printGenParticleInfo(w_from_top, -1);
      }

      const GenParticle *lep = nullptr;
      for (int idau = w_from_top->D1; idau <= w_from_top->D2; ++idau) {
        const auto *dau = genParticles_.at(idau);
        auto pdgid = std::abs(dau->PID);
        if (pdgid == ParticleID::p_eminus || pdgid == ParticleID::p_muminus) {
          // use final version here!
          lep = getFinal(dau);
          break;
        }
      }
      if (!lep)
        throw std::logic_error("[FatJetMatching::top_label] Cannot find charged lepton from leptonic W decay!");

      double dr_b = deltaR(jet, b_from_top);
      double dr_l = deltaR(jet, lep);
      if (debug_) {
        using namespace std;
        cout << "deltaR(jet, b)     : " << dr_b << endl;
        cout << "deltaR(jet, l)     : " << dr_l << endl;
        cout << "pdgid(l)           : " << lep->PID << endl;
      }

      if (dr_b < jetR_ && dr_l < jetR_) {
        auto pdgid = std::abs(lep->PID);
        if (pdgid == ParticleID::p_eminus) {
          return std::make_pair(FatJetLabel::Top_ben, top);
        } else if (pdgid == ParticleID::p_muminus) {
          return std::make_pair(FatJetLabel::Top_bmn, top);
        }
      }
    }

    return std::make_pair(FatJetLabel::Invalid, nullptr);
  }

  std::pair<FatJetLabel, const GenParticle *> w_label(const Jet *jet, const GenParticle *parton) {
    auto w = getFinal(parton);
    if (isHadronic(w)) {
      if (event_type_ == EventType::QCD) {
        event_type_ = EventType::W;
      }

      if (debug_) {
        using namespace std;
        cout << "jet: (" << jet->PT << ", " << jet->Eta << ", " << jet->Phi << ", " << jet->P4().Energy() << ")"
             << endl;
        cout << "W:   ";
        printGenParticleInfo(w, -1);
      }

      auto wdaus = getDaughterQuarks(w);
      if (wdaus.size() < 2)
        throw std::logic_error("[FatJetMatching::w_label] W decay has less than 2 quarks!");
      //    if (wdaus.size() >= 2)
      {
        double dr_q1 = deltaR(jet, wdaus.at(0));
        double dr_q2 = deltaR(jet, wdaus.at(1));
        if (dr_q1 > dr_q2) {
          // swap q1 and q2 so that dr_q1<=dr_q2
          std::swap(dr_q1, dr_q2);
          std::swap(wdaus.at(0), wdaus.at(1));
        }
        auto pdgid_q1 = std::abs(wdaus.at(0)->PID);
        auto pdgid_q2 = std::abs(wdaus.at(1)->PID);

        if (debug_) {
          using namespace std;
          cout << "deltaR(jet, q1)    : " << dr_q1 << endl;
          cout << "deltaR(jet, q2)    : " << dr_q2 << endl;
          cout << "pdgid(q1)        : " << pdgid_q1 << endl;
          cout << "pdgid(q2)        : " << pdgid_q2 << endl;
        }

        if (dr_q1 < jetR_ && dr_q2 < jetR_) {
          if (pdgid_q1 >= ParticleID::p_c || pdgid_q2 >= ParticleID::p_c) {
            return std::make_pair(FatJetLabel::W_cq, w);
          } else {
            return std::make_pair(FatJetLabel::W_qq, w);
          }
        }
      }
    }

    return std::make_pair(FatJetLabel::Invalid, nullptr);
  }

  std::pair<FatJetLabel, const GenParticle *> z_label(const Jet *jet, const GenParticle *parton) {
    auto z = getFinal(parton);
    if (isHadronic(z)) {
      if (event_type_ == EventType::QCD) {
        event_type_ = EventType::Z;
      }

      if (debug_) {
        using namespace std;
        cout << "jet: (" << jet->PT << ", " << jet->Eta << ", " << jet->Phi << ", " << jet->P4().Energy() << ")"
             << endl;
        cout << "Z:   ";
        printGenParticleInfo(z, -1);
      }

      auto zdaus = getDaughterQuarks(z);
      if (zdaus.size() < 2)
        throw std::logic_error("[FatJetMatching::z_label] Z decay has less than 2 quarks!");
      //    if (zdaus.size() >= 2)
      {
        double dr_q1 = deltaR(jet, zdaus.at(0));
        double dr_q2 = deltaR(jet, zdaus.at(1));
        if (dr_q1 > dr_q2) {
          // swap q1 and q2 so that dr_q1<=dr_q2
          std::swap(dr_q1, dr_q2);
          std::swap(zdaus.at(0), zdaus.at(1));
        }
        auto pdgid_q1 = std::abs(zdaus.at(0)->PID);
        auto pdgid_q2 = std::abs(zdaus.at(1)->PID);

        if (debug_) {
          using namespace std;
          cout << "deltaR(jet, q1)    : " << dr_q1 << endl;
          cout << "deltaR(jet, q2)    : " << dr_q2 << endl;
          cout << "pdgid(q1)        : " << pdgid_q1 << endl;
          cout << "pdgid(q2)        : " << pdgid_q2 << endl;
        }

        if (dr_q1 < jetR_ && dr_q2 < jetR_) {
          if (pdgid_q1 == ParticleID::p_b && pdgid_q2 == ParticleID::p_b) {
            return std::make_pair(FatJetLabel::Z_bb, z);
          } else if (pdgid_q1 == ParticleID::p_c && pdgid_q2 == ParticleID::p_c) {
            return std::make_pair(FatJetLabel::Z_cc, z);
          } else {
            return std::make_pair(FatJetLabel::Z_qq, z);
          }
        }
      }
    }

    return std::make_pair(FatJetLabel::Invalid, nullptr);
  }

  std::pair<FatJetLabel, const GenParticle *> higgs_label(const Jet *jet, const GenParticle *parton) {
    auto higgs = getFinal(parton);
    auto daus = getDaughters(higgs);

    bool is_hvv = false;
    if (daus.size() > 2) {
      // e.g., h->Vqq or h->qqqq
      is_hvv = true;
    } else {
      // e.g., h->VV*
      for (const auto *p : daus) {
        auto pdgid = std::abs(p->PID);
        if (pdgid == ParticleID::p_Wplus || pdgid == ParticleID::p_Z0) {
          is_hvv = true;
          break;
        }
      }
    }

    if (is_hvv) {
      if (event_type_ == EventType::QCD) {
        event_type_ = EventType::Higgs;
      }

      // h->WW or h->ZZ
      std::vector<const GenParticle *> hvv_quarks;
      std::vector<const GenParticle *> hvv_leptons;
      for (const auto *p : daus) {
        auto pdgid = std::abs(p->PID);
        if (pdgid >= ParticleID::p_d && pdgid <= ParticleID::p_b) {
          hvv_quarks.push_back(p);
        } else if (pdgid == ParticleID::p_eminus || pdgid == ParticleID::p_muminus) {
          hvv_leptons.push_back(getFinal(p));
        } else if (pdgid == ParticleID::p_Wplus || pdgid == ParticleID::p_Z0) {
          auto v_daus = getDaughters(getFinal(p));
          for (const auto *vdau : v_daus) {
            auto pdgid = std::abs(vdau->PID);
            if (pdgid >= ParticleID::p_d && pdgid <= ParticleID::p_b) {
              hvv_quarks.push_back(vdau);
            } else if (pdgid == ParticleID::p_eminus || pdgid == ParticleID::p_muminus) {
              hvv_leptons.push_back(getFinal(vdau));
            }
          }
        }
      }

      if (debug_) {
        using namespace std;
        cout << "Found " << hvv_quarks.size() << " quarks from Higgs decay" << endl;
        for (const auto *gp : hvv_quarks) {
          using namespace std;
          printGenParticleInfo(gp, -1);
          cout << " ... dR(q, jet) = " << deltaR(gp, jet) << endl;
        }
        cout << "Found " << hvv_leptons.size() << " leptons from Higgs decay" << endl;
        for (const auto *gp : hvv_leptons) {
          using namespace std;
          printGenParticleInfo(gp, -1);
          cout << " ... dR(lep, jet) = " << deltaR(gp, jet) << endl;
        }
      }

      unsigned n_quarks_in_jet = 0;
      for (const auto *gp : hvv_quarks) {
        auto dr = deltaR(gp, jet);
        if (dr < jetR_) {
          ++n_quarks_in_jet;
        }
      }
      unsigned n_leptons_in_jet = 0;
      for (const auto *gp : hvv_leptons) {
        auto dr = deltaR(gp, jet);
        if (dr < jetR_) {
          ++n_leptons_in_jet;
        }
      }

      if (n_quarks_in_jet >= 4) {
        return std::make_pair(FatJetLabel::H_ww4q, higgs);
      } else if (n_quarks_in_jet == 2 && n_leptons_in_jet == 1) {
        return std::make_pair(FatJetLabel::H_ww2q1l, higgs);
      }
    } else if (isHadronic(higgs, true)) {
      // direct h->qq
      if (event_type_ == EventType::QCD) {
        event_type_ = EventType::Higgs;
      }

      if (debug_) {
        using namespace std;
        cout << "jet: (" << jet->PT << ", " << jet->Eta << ", " << jet->Phi << ", " << jet->P4().Energy() << ")"
             << endl;
        cout << "H:   ";
        printGenParticleInfo(higgs, -1);
      }

      auto hdaus = getDaughterQuarks(higgs, true);
      if (hdaus.size() < 2)
        throw std::logic_error("[FatJetMatching::higgs_label] Higgs decay has less than 2 quarks!");
      //    if (zdaus.size() >= 2)
      {
        double dr_q1 = deltaR(jet, hdaus.at(0));
        double dr_q2 = deltaR(jet, hdaus.at(1));
        if (dr_q1 > dr_q2) {
          // swap q1 and q2 so that dr_q1<=dr_q2
          std::swap(dr_q1, dr_q2);
          std::swap(hdaus.at(0), hdaus.at(1));
        }
        auto pdgid_q1 = std::abs(hdaus.at(0)->PID);
        auto pdgid_q2 = std::abs(hdaus.at(1)->PID);

        if (debug_) {
          using namespace std;
          cout << "deltaR(jet, q1)    : " << dr_q1 << endl;
          cout << "deltaR(jet, q2)    : " << dr_q2 << endl;
          cout << "pdgid(q1)        : " << pdgid_q1 << endl;
          cout << "pdgid(q2)        : " << pdgid_q2 << endl;
        }

        if (dr_q1 < jetR_ && dr_q2 < jetR_) {
          if (pdgid_q1 == ParticleID::p_b && pdgid_q2 == ParticleID::p_b) {
            return std::make_pair(FatJetLabel::H_bb, higgs);
          } else if (pdgid_q1 == ParticleID::p_c && pdgid_q2 == ParticleID::p_c) {
            return std::make_pair(FatJetLabel::H_cc, higgs);
          } else if (pdgid_q1 == ParticleID::p_g && pdgid_q2 == ParticleID::p_g) {
            return std::make_pair(FatJetLabel::H_gg, higgs);
          } else {
            return std::make_pair(FatJetLabel::H_qq, higgs);
          }
        }
      }
    }

    return std::make_pair(FatJetLabel::Invalid, nullptr);
  }

private:
  void printGenInfoHeader() const {
    using namespace std;
    cout << right << setw(6) << "#"
         << " " << setw(10) << "pdgId"
         << "  "
         << "Chg"
         << "  " << setw(10) << "Mass"
         << "  " << setw(48) << " Momentum" << left << "  " << setw(10) << "Mothers"
         << " " << setw(30) << "Daughters" << endl;
  }

  void printGenParticleInfo(const GenParticle *genParticle, const int idx) const {
    using namespace std;
    cout << right << setw(3) << genParticle->Status;
    cout << right << setw(3) << idx << " " << setw(10) << genParticle->PID << "  ";
    cout << right << "  " << setw(3) << genParticle->Charge << "  "
         << TString::Format("%10.3g", genParticle->Mass < 1e-5 ? 0 : genParticle->Mass);
    cout << left << setw(50)
         << TString::Format("  (E=%6.4g pT=%6.4g eta=%7.3g phi=%7.3g)",
                            genParticle->P4().Energy(),
                            genParticle->PT,
                            genParticle->Eta,
                            genParticle->Phi);

    TString mothers;
    if (genParticle->M1 >= 0) {
      mothers += genParticle->M1;
    }
    if (genParticle->M2 >= 0) {
      mothers += ",";
      mothers += genParticle->M2;
    }
    cout << "  " << setw(10) << mothers;

    TString daughters;
    for (unsigned int iDau = genParticle->D1; iDau <= genParticle->D2; ++iDau) {
      if (daughters.Length())
        daughters += ",";
      daughters += iDau;
    }
    cout << " " << setw(30) << daughters << endl;
  }

  const GenParticle *getFinal(const GenParticle *particle) {
    // will mark intermediate particles as processed
    if (!particle)
      return nullptr;
    processed_.insert(particle);
    const GenParticle *final = particle;

    while (final->D1 >= 0) {
      const GenParticle *chain = nullptr;
      for (unsigned idau = final->D1; idau <= final->D2; ++idau) {
        if (genParticles_.at(idau)->PID == particle->PID) {
          chain = genParticles_.at(idau);
          processed_.insert(chain);
          break;
        }
      }
      if (!chain)
        break;
      final = chain;
    }
    return final;
  }

  bool isHadronic(const GenParticle *particle, bool allow_gluon = false) const {
    // particle needs to be the final version before decay
    if (!particle)
      throw std::invalid_argument("[FatJetMatching::isHadronic()] Null particle!");
    for (const auto *dau : getDaughters(particle)) {
      auto pdgid = std::abs(dau->PID);
      if (pdgid >= ParticleID::p_d && pdgid <= ParticleID::p_b)
        return true;
      if (allow_gluon && pdgid == ParticleID::p_g)
        return true;
    }
    return false;
  }

  std::vector<const GenParticle *> getDaughters(const GenParticle *particle) const {
    std::vector<const GenParticle *> daughters;
    for (int idau = particle->D1; idau <= particle->D2; ++idau) {
      daughters.push_back(genParticles_.at(idau));
    }
    return daughters;
  }

  std::vector<const GenParticle *> getDaughterQuarks(const GenParticle *particle, bool allow_gluon = false) {
    std::vector<const GenParticle *> daughters;
    for (int idau = particle->D1; idau <= particle->D2; ++idau) {
      const auto *dau = genParticles_.at(idau);
      auto pdgid = std::abs(dau->PID);
      if (pdgid >= ParticleID::p_d && pdgid <= ParticleID::p_b) {
        daughters.push_back(dau);
      }
      if (allow_gluon && pdgid == ParticleID::p_g) {
        daughters.push_back(dau);
      }
    }
    return daughters;
  }

private:
  double jetR_ = 0.8;
  bool debug_ = false;
  std::vector<const GenParticle *> genParticles_;
  std::unordered_set<const GenParticle *> processed_;
  EventType event_type_ = EventType::QCD;
};

// charged pion mass (PDG), the mass CMS particle flow assigns to charged hadrons
constexpr double kChargedPionMass = 0.13957039;

struct ParticleInfo {
  // Uses the stored four-momentum, not GenParticle::Mass: Delphes' HepMC2 reader rescales the momentum of a file
  // written in MeV to GeV but copies the mass field unscaled.
  ParticleInfo(const GenParticle *particle) {
    pt = particle->PT;
    eta = particle->Eta;
    phi = particle->Phi;
    px = particle->Px;
    py = particle->Py;
    pz = particle->Pz;
    energy = particle->E;
    mass = particle->P4().M();
    charge = particle->Charge;
    pid = particle->PID;
  }

  // With chargedHadronPionMass, a charged candidate that is not an electron or a muon gets the pion mass at fixed
  // track momentum, as in CMS particle flow; Delphes gives it its true mass, which identifies kaons and protons.
  // Neutral hadrons and photons are massless (energy = |p|) in both Delphes and CMS particle flow.
  ParticleInfo(const ParticleFlowCandidate *particle, bool chargedHadronPionMass) {
    pt = particle->PT;
    eta = particle->Eta;
    phi = particle->Phi;
    mass = particle->Mass;
    if (chargedHadronPionMass && particle->Charge != 0 && std::abs(particle->PID) != 11 &&
        std::abs(particle->PID) != 13) {
      mass = kChargedPionMass;
    }
    p4 = ROOT::Math::PtEtaPhiMVector(pt, eta, phi, mass);
    px = p4.px();
    py = p4.py();
    pz = p4.pz();
    energy = p4.energy();
    charge = particle->Charge;
    pid = particle->PID;
    d0 = particle->D0;
    d0err = particle->ErrorD0;
    dz = particle->DZ;
    dzerr = particle->ErrorDZ;
  }

  double pt;
  double eta;
  double phi;
  double mass;
  double px;
  double py;
  double pz;
  double energy;
  ROOT::Math::PtEtaPhiMVector p4;

  int charge;
  int pid;

  float d0 = 0;
  float d0err = 0;
  float dz = 0;
  float dzerr = 0;
};

// Generator truth graph of one event, following the CMS MC-truth graph (cms-sw/cmssw PhysicsTools/TruthInfo, by
// F. Pantaleo) on the GEN side:
//   - per-particle reco::GenStatusFlags bits, ported from PhysicsTools/HepMCCandAlgos MCTruthHelper, so they read
//     like NanoAOD GenPart_statusFlags;
//   - three history modes:
//       0: the full generator record;
//       1: the CMS default for the main event (TruthLogicalGraphPostProcessor collapseIntermediateGenParticles): the
//          parton shower is kept, and pure 1 -> 1 copy chains of the same species are merged into their last copy,
//          which inherits the production vertex of the first;
//       2: additionally the shower collapse CMS applies to pile-up (truth::collapseGenShower: keep status 1,
//          isHardProcess, and the last copy of anything that is not a shower object; re-attach every survivor to its
//          nearest surviving ancestors), with two additions: partons produced in a decayed hadron (e.g.
//          Upsilon -> g g g) are kept, since they are physics, not shower, and so is the last copy of a top;
//   - the GEN vertex reasons of truth::genVertexReason, with the truth::VertexReason numbering, stamped on the
//     complete GEN topology before any collapse (as CMS does), and Unknown for the beam-side vertices (CMS models
//     those as artificial vertices);
//   - the truth levels of PhysicsTools/TruthInfo/interface/TruthLevels.h that exist without SIM, with the
//     truth::LevelFlag bit values.
//
// Mother links: D1..D2 is a contiguous daughter range in the HepMC2, HepMC3 and Pythia8 Delphes readers, while M1..M2
// is not always a range (HepMC: first/last incoming particle of the production vertex), so mothers are built by
// inverting the daughter ranges, plus the M1/M2 endpoints themselves.
//
// Beyond Pythia (the CMS rules assume Pythia status codes):
//   - a record that is not a DAG is made one: Sherpa lists the incoming hard-process partons among the outputs of its
//     single shower vertex, whose inputs include the final-state partons. Inside each strongly connected component, the
//     mother links that do not lead deeper from the beams (BFS depth) are dropped;
//   - Herwig clusters (81) are treated like Pythia strings/clusters, and ThePEG remnants (82) like beam pseudoparticles;
//   - a parton splitting into status-11 partons (the Herwig and Sherpa shower code) is ShowerBranching, and partons
//     turning into a cluster or string are Hadronization. isHardProcess, and with it the HardProcess and PartonJets
//     levels and the HardScatter reason, needs Pythia codes or the status 3 Sherpa gives its hard-process legs.
class GenTruthGraph {
public:
  enum StatusBit {
    kIsPrompt = 0,
    kIsDecayedLeptonHadron,
    kIsTauDecayProduct,
    kIsPromptTauDecayProduct,
    kIsDirectTauDecayProduct,
    kIsDirectPromptTauDecayProduct,
    kIsDirectHadronDecayProduct,
    kIsHardProcess,
    kFromHardProcess,
    kIsHardProcessTauDecayProduct,
    kIsDirectHardProcessTauDecayProduct,
    kFromHardProcessBeforeFSR,
    kIsFirstCopy,
    kIsLastCopy,
    kIsLastCopyBeforeFSR
  };

  enum LevelFlag : uint32_t {
    HardProcess = 1u << 1,
    StableDecayProducts = 1u << 2,
    Signal = 1u << 4,
    ReconstructableFromSignal = 1u << 5,
    PartonJets = 1u << 7,
    BHadrons = 1u << 8,
    CHadrons = 1u << 9,
    ReconstructableFinalState = 1u << 10,
    TauVisibleHadronic = 1u << 11,
    TauVisibleLeptonic = 1u << 12,
  };

  enum VertexReason : int { Unknown = 0, Decay = 2, HardScatter = 17, ShowerBranching = 18, Hadronization = 19 };

  enum Mode { kFull = 0, kCollapseCopies = 1, kCollapseShower = 2 };

  explicit GenTruthGraph(int mode = kCollapseCopies) : mode_(mode) {}

  void build(const TClonesArray *branchParticle) {
    n_ = branchParticle->GetEntriesFast();
    particles_.resize(n_);
    pid_.resize(n_);
    status_.resize(n_);
    index_.clear();
    for (int i = 0; i < n_; ++i) {
      particles_[i] = (const GenParticle *)branchParticle->At(i);
      pid_[i] = particles_[i]->PID;
      status_[i] = particles_[i]->Status;
      index_[particles_[i]] = i;
    }
    buildLinks();
    statusFlags_.assign(n_, 0);
    for (int i = 0; i < n_; ++i) {
      statusFlags_[i] = computeStatusFlags(i);
    }
    buildCollapsed();
    buildVertices();
    if (mode_ >= kCollapseCopies)
      collapseCopyChains();
    buildLevels();
  }

  // index of the particle in the Particle branch, -1 if not found
  int index(const GenParticle *gp) const {
    auto it = index_.find(gp);
    return it == index_.end() ? -1 : it->second;
  }

  const GenParticle *particle(int i) const { return particles_[i]; }
  bool kept(int i) const { return keep_[i]; }
  uint16_t statusFlags(int i) const { return statusFlags_[i]; }
  uint32_t levelFlags(int i) const { return levelFlags_[i]; }
  int vertex(int i) const { return vertexOf_[i]; }
  int vertexReason(int v) const { return v < 0 ? Unknown : vertexReason_[v]; }
  // parents in the stored (collapsed or full) graph
  const std::vector<int> &parents(int i) const { return parents_[i]; }
  // generator records that were not DAGs so far, and the mother links dropped to make them one
  long eventsWithCycles() const { return eventsWithCycles_; }
  long droppedCycleLinks() const { return droppedCycleLinks_; }

  // all stored ancestors of the seeds, including the seeds themselves, sorted by Particle-branch index
  std::vector<int> ancestry(const std::vector<int> &seeds) const {
    std::vector<char> visited(n_, 0);
    std::vector<int> stack;
    for (int i : seeds) {
      if (i >= 0 && !visited[i]) {
        visited[i] = 1;
        stack.push_back(i);
      }
    }
    while (!stack.empty()) {
      int i = stack.back();
      stack.pop_back();
      for (int m : parents_[i]) {
        if (!visited[m]) {
          visited[m] = 1;
          stack.push_back(m);
        }
      }
    }
    std::vector<int> result;
    for (int i = 0; i < n_; ++i) {
      if (visited[i])
        result.push_back(i);
    }
    return result;
  }

  // Signal and ReconstructableFromSignal bits for one resonance (the one the jet was matched to): the Signal root is
  // the most upstream stored copy of it, and the walk down from there is the TruthLevels reconstructable walk.
  std::unordered_map<int, uint32_t> signalFlags(int resonance) const {
    std::unordered_map<int, uint32_t> flags;
    if (resonance < 0)
      return flags;
    int root = firstCopy(resonance);
    while (root >= 0 && !keep_[root])
      root = nextCopy(root);
    if (root < 0)
      return flags;
    flags[root] |= Signal;
    std::vector<int> legs = reconstructableLegsFrom({root});
    dropCoveredMembers(legs, false);
    for (int i : legs)
      flags[i] |= ReconstructableFromSignal;
    return flags;
  }

  static bool isParton(int pdgId) {
    int a = std::abs(pdgId);
    return (a >= 1 && a <= 6) || a == 21;
  }

  // Pythia strings/clusters (91-94) and Herwig clusters (81)
  static bool isStringOrCluster(int pdgId) {
    int a = std::abs(pdgId);
    return a == 81 || (a >= 91 && a <= 94);
  }

  // TruthInfo isShowerObject: partons, diquarks, strings/clusters and generator pseudoparticles (plus the Herwig
  // cluster 81 and the ThePEG remnant 82)
  static bool isShowerObject(int pdgId) {
    int a = std::abs(pdgId);
    if (isParton(a))
      return true;
    if (isStringOrCluster(a) || a == 82)
      return true;
    if (a == 990)
      return true;
    if (a >= 1000 && a <= 9999 && (a / 10) % 10 == 0 && (a / 100) % 10 != 0)
      return true;
    return a >= 9900000 && a < 1000000000;
  }

  // HepPDT::ParticleID::isHadron on the PDG numbering digits (mesons and baryons)
  static bool isHadron(int pdgId) {
    int a = std::abs(pdgId);
    if (a < 100 || a >= 1000000000 || (a >= 9900000))
      return false;
    int nq1 = (a / 1000) % 10, nq2 = (a / 100) % 10, nq3 = (a / 10) % 10;
    if (nq3 == 0 || nq2 == 0)
      return false;  // diquarks and non-hadron codes
    return true;
  }

  static bool hadronHasQuark(int pdgId, int flavor) {
    int a = std::abs(pdgId);
    if (a < 100 || a >= 1000000000)
      return false;
    if (a >= 1000 && a <= 9999 && (a / 10) % 10 == 0 && (a / 100) % 10 != 0)
      return false;
    return (a / 1000) % 10 == flavor || (a / 100) % 10 == flavor || (a / 10) % 10 == flavor;
  }

private:
  void addMother(int dau, int mom) {
    if (dau < 0 || mom < 0 || dau >= n_ || mom >= n_ || dau == mom)
      return;
    auto &v = mothers_[dau];
    if (std::find(v.begin(), v.end(), mom) == v.end())
      v.push_back(mom);
  }

  void buildLinks() {
    mothers_.assign(n_, {});
    for (int i = 0; i < n_; ++i) {
      const auto *gp = particles_[i];
      addMother(i, gp->M1);
      addMother(i, gp->M2);
    }
    for (int i = 0; i < n_; ++i) {
      const auto *gp = particles_[i];
      if (gp->D1 < 0)
        continue;
      if (gp->D2 > gp->D1) {
        for (int d = gp->D1; d <= gp->D2; ++d)
          addMother(d, i);
      } else {
        // D2 < D1: two separate daughters (Pythia8 convention)
        addMother(gp->D1, i);
        addMother(gp->D2, i);
      }
    }
    breakCycles();
    daughters_.assign(n_, {});
    for (int i = 0; i < n_; ++i) {
      for (int m : mothers_[i])
        daughters_[m].push_back(i);
    }
  }

  // Drop the mother links that close a cycle: inside a strongly connected component (Tarjan), a link from a mother that
  // is not strictly shallower than its daughter, in BFS depth from the particles without mothers. Every remaining link
  // inside a component goes strictly deeper and links between components follow their DAG, so the result is acyclic.
  // A DAG is left untouched.
  void breakCycles() {
    std::vector<std::vector<int>> dau(n_);
    for (int i = 0; i < n_; ++i) {
      for (int m : mothers_[i])
        dau[m].push_back(i);
    }

    std::vector<int> comp(n_, -1), low(n_, 0), order(n_, -1), stack;
    std::vector<char> onStack(n_, 0);
    std::vector<std::pair<int, size_t>> calls;
    int counter = 0, ncomp = 0;
    bool anyCycle = false;
    for (int s = 0; s < n_; ++s) {
      if (order[s] >= 0)
        continue;
      order[s] = low[s] = counter++;
      stack.push_back(s);
      onStack[s] = 1;
      calls.emplace_back(s, 0);
      while (!calls.empty()) {
        const int v = calls.back().first;
        if (calls.back().second < dau[v].size()) {
          const int w = dau[v][calls.back().second++];
          if (order[w] < 0) {
            order[w] = low[w] = counter++;
            stack.push_back(w);
            onStack[w] = 1;
            calls.emplace_back(w, 0);
          } else if (onStack[w]) {
            low[v] = std::min(low[v], order[w]);
          }
          continue;
        }
        if (low[v] == order[v]) {
          int w = -1, size = 0;
          do {
            w = stack.back();
            stack.pop_back();
            onStack[w] = 0;
            comp[w] = ncomp;
            ++size;
          } while (w != v);
          anyCycle |= size > 1;
          ++ncomp;
        }
        calls.pop_back();
        if (!calls.empty())
          low[calls.back().first] = std::min(low[calls.back().first], low[v]);
      }
    }
    if (!anyCycle)
      return;

    std::vector<int> depth(n_, std::numeric_limits<int>::max()), queue;
    for (int i = 0; i < n_; ++i) {
      if (mothers_[i].empty()) {
        depth[i] = 0;
        queue.push_back(i);
      }
    }
    for (size_t q = 0; q < queue.size(); ++q) {
      for (int d : dau[queue[q]]) {
        if (depth[d] == std::numeric_limits<int>::max()) {
          depth[d] = depth[queue[q]] + 1;
          queue.push_back(d);
        }
      }
    }
    for (int i = 0; i < n_; ++i) {
      auto &v = mothers_[i];
      const size_t before = v.size();
      v.erase(std::remove_if(v.begin(),
                             v.end(),
                             [&](int m) { return comp[m] == comp[i] && depth[m] >= depth[i]; }),
              v.end());
      droppedCycleLinks_ += before - v.size();
    }
    ++eventsWithCycles_;
  }

  // ---- MCTruthHelper port (indices instead of pointers, -1 for none) ----
  int mother(int p) const { return mothers_[p].empty() ? -1 : mothers_[p][0]; }

  int previousCopy(int p) const {
    for (int m : mothers_[p]) {
      if (pid_[m] == pid_[p])
        return m;
    }
    return -1;
  }

  int nextCopy(int p) const {
    for (int d : daughters_[p]) {
      if (pid_[d] == pid_[p])
        return d;
    }
    return -1;
  }

  int firstCopy(int p) const {
    std::unordered_set<int> seen;
    while (previousCopy(p) >= 0) {
      seen.insert(p);
      p = previousCopy(p);
      if (seen.count(p))
        return -1;
    }
    return p;
  }

  int lastCopy(int p) const {
    std::unordered_set<int> seen;
    while (nextCopy(p) >= 0) {
      seen.insert(p);
      p = nextCopy(p);
      if (seen.count(p))
        return -1;
    }
    return p;
  }

  int uniqueMother(int p) const {
    int mo = p;
    std::unordered_set<int> seen;
    while (mo >= 0 && pid_[mo] == pid_[p]) {
      seen.insert(mo);
      mo = mother(mo);
      if (seen.count(mo))
        return -1;
    }
    return mo;
  }

  int lastDaughterCopyBeforeFSR(int p) const {
    int pcopy = p;
    std::unordered_set<int> seen;
    bool hasDaughterCopy = true;
    while (hasDaughterCopy) {
      seen.insert(pcopy);
      hasDaughterCopy = false;
      for (int d : daughters_[pcopy]) {
        if (pid_[d] == 21 || pid_[d] == 22)
          return pcopy;
      }
      for (int d : daughters_[pcopy]) {
        if (pid_[d] == pid_[p]) {
          pcopy = d;
          hasDaughterCopy = true;
          break;
        }
      }
      if (hasDaughterCopy && seen.count(pcopy))
        return -1;
    }
    return pcopy;
  }

  int lastCopyBeforeFSR(int p) const {
    int first = firstCopy(p);
    return first < 0 ? -1 : lastDaughterCopyBeforeFSR(first);
  }

  bool isLastCopy(int p) const { return lastCopy(p) == p; }

  bool isDecayedLeptonHadron(int p) const {
    int a = std::abs(pid_[p]);
    return status_[p] == 2 && (isHadron(pid_[p]) || a == 13 || a == 15) && isLastCopy(p);
  }

  int findDecayedMother(int p, int abspdgid = 0) const {
    int mo = mother(p);
    std::unordered_set<int> seen;
    while (mo >= 0 && ((abspdgid && std::abs(pid_[mo]) != abspdgid) || !isDecayedLeptonHadron(mo))) {
      seen.insert(mo);
      mo = mother(mo);
      if (seen.count(mo))
        return -1;
    }
    return mo;
  }

  bool isPrompt(int p) const { return findDecayedMother(p) < 0; }

  bool isHardProcess(int p) const {
    if (status_[p] == 3)
      return true;
    if (status_[p] > 20 && status_[p] < 30)
      return true;
    if (status_[p] == 1 || status_[p] == 2) {
      int um = mother(p);
      if (um >= 0) {
        int fc = firstCopy(um);
        bool fromResonance = fc >= 0 && status_[fc] == 22;
        int umNext = nextCopy(um);
        bool fsrBranching = umNext >= 0 && status_[umNext] > 50 && status_[umNext] < 60;
        if (fromResonance && !fsrBranching)
          return true;
      }
    }
    return false;
  }

  int hardProcessMotherCopy(int p) const {
    if (isHardProcess(p))
      return p;
    int pcopy = p;
    std::unordered_set<int> seen;
    while (previousCopy(pcopy) >= 0) {
      seen.insert(pcopy);
      pcopy = previousCopy(pcopy);
      if (isHardProcess(pcopy))
        return pcopy;
      if (seen.count(pcopy))
        break;
    }
    return -1;
  }

  bool fromHardProcess(int p) const { return hardProcessMotherCopy(p) >= 0; }

  bool fromHardProcessBeforeFSR(int p) const {
    if (status_[p] == 3)
      return true;
    int hpc = hardProcessMotherCopy(p);
    if (hpc < 0)
      return false;
    if (status_[hpc] == 21 && p == hpc)
      return true;
    if (status_[hpc] == 22 && isLastCopy(p))
      return true;
    if ((status_[hpc] == 23 || status_[hpc] == 1) && p == lastDaughterCopyBeforeFSR(hpc))
      return true;
    return false;
  }

  uint16_t computeStatusFlags(int p) const {
    const int tau = findDecayedMother(p, 15);
    const int dm = findDecayedMother(p);
    const int um = uniqueMother(p);
    std::bitset<15> f;
    f[kIsPrompt] = dm < 0;
    f[kIsDecayedLeptonHadron] = isDecayedLeptonHadron(p);
    f[kIsTauDecayProduct] = tau >= 0;
    f[kIsPromptTauDecayProduct] = tau >= 0 && isPrompt(tau);
    f[kIsDirectTauDecayProduct] = tau >= 0 && tau == dm;
    f[kIsDirectPromptTauDecayProduct] = tau >= 0 && tau == dm && isPrompt(tau);
    f[kIsDirectHadronDecayProduct] = um >= 0 && isHadron(pid_[um]) && isDecayedLeptonHadron(um);
    f[kIsHardProcess] = isHardProcess(p);
    f[kFromHardProcess] = fromHardProcess(p);
    f[kIsHardProcessTauDecayProduct] = tau >= 0 && isDecayedLeptonHadron(tau) && fromHardProcess(tau);
    f[kIsDirectHardProcessTauDecayProduct] = tau >= 0 && tau == dm && fromHardProcess(tau);
    f[kFromHardProcessBeforeFSR] = fromHardProcessBeforeFSR(p);
    f[kIsFirstCopy] = firstCopy(p) == p;
    f[kIsLastCopy] = isLastCopy(p);
    f[kIsLastCopyBeforeFSR] = lastCopyBeforeFSR(p) == p;
    return static_cast<uint16_t>(f.to_ulong());
  }

  // ---- collapse (truth::collapseGenShower) ----
  bool keepParticle(int p) const {
    if (mode_ < kCollapseShower)
      return true;
    if (status_[p] == 1)
      return true;
    if (statusFlags_[p] & (1u << kIsHardProcess))
      return true;
    // the top decays before it can hadronize, so its last copy is kept like any other resonance (CMS keeps it only
    // through isHardProcess, which generators without Pythia status codes, e.g. Herwig, never set)
    if ((statusFlags_[p] & (1u << kIsLastCopy)) && (!isShowerObject(pid_[p]) || std::abs(pid_[p]) == 6))
      return true;
    // addition to the CMS rule: partons from a hadron decay, e.g. Upsilon -> g g g (the beam protons are not decays)
    if (isParton(pid_[p])) {
      for (int m : mothers_[p]) {
        if (isHadron(pid_[m]) && status_[m] == 2)
          return true;
      }
    }
    return false;
  }

  static void sortUnique(std::vector<int> &v) {
    std::sort(v.begin(), v.end());
    v.erase(std::unique(v.begin(), v.end()), v.end());
  }

  void buildCollapsed() {
    keep_.assign(n_, 0);
    for (int i = 0; i < n_; ++i)
      keep_[i] = keepParticle(i);

    // nearest kept ancestors-or-self of every particle; iterative and memoized, cycle-safe
    std::vector<std::vector<int>> nearestKept(n_);
    std::vector<char> state(n_, 0);  // 0 = new, 1 = in progress, 2 = done
    std::vector<int> stack;
    for (int seed = 0; seed < n_; ++seed) {
      if (state[seed] == 2)
        continue;
      stack.push_back(seed);
      while (!stack.empty()) {
        int i = stack.back();
        if (state[i] == 2) {
          stack.pop_back();
          continue;
        }
        if (state[i] == 0) {
          state[i] = 1;
          if (keep_[i]) {
            nearestKept[i].push_back(i);
            state[i] = 2;
            stack.pop_back();
            continue;
          }
          for (int m : mothers_[i]) {
            if (state[m] == 0)
              stack.push_back(m);
          }
          continue;
        }
        for (int m : mothers_[i]) {
          if (state[m] == 2)
            nearestKept[i].insert(nearestKept[i].end(), nearestKept[m].begin(), nearestKept[m].end());
        }
        sortUnique(nearestKept[i]);
        state[i] = 2;
        stack.pop_back();
      }
    }

    parents_.assign(n_, {});
    children_.assign(n_, {});
    for (int i = 0; i < n_; ++i) {
      if (!keep_[i])
        continue;
      for (int m : mothers_[i]) {
        for (int a : nearestKept[m]) {
          // a particle produced at the same vertex must not become an ancestor
          if (a != i && mothers_[a] != mothers_[i])
            parents_[i].push_back(a);
        }
      }
      sortUnique(parents_[i]);
      for (int a : parents_[i])
        children_[a].push_back(i);
    }
  }

  // ---- copy chains (collapseIntermediateGenParticleChains) ----
  // A stored particle that is not stable, has exactly one stored child, of the same species, which in turn has no
  // other parent, is a 1 -> 1 copy step. Each chain is replaced by its last copy, which takes the production vertex
  // of the first. Unlike CMS, the merged particle also takes the union of the chain's status flags: otherwise a
  // hard-process quark whose only later step is a recoil copy loses isHardProcess and drops out of the HardProcess
  // and PartonJets levels.
  void collapseCopyChains() {
    std::vector<int> directChild(n_, -1);
    for (int p = 0; p < n_; ++p) {
      if (!keep_[p] || status_[p] == 1 || children_[p].size() != 1)
        continue;
      int c = children_[p][0];
      if (pid_[c] == pid_[p] && parents_[c].size() == 1)
        directChild[p] = c;
    }
    std::vector<int> rep(n_, -1);
    for (int p = 0; p < n_; ++p) {
      if (!keep_[p] || rep[p] >= 0)
        continue;
      std::vector<int> path;
      int cur = p;
      while (rep[cur] < 0 && directChild[cur] >= 0 && path.size() < static_cast<size_t>(n_)) {
        path.push_back(cur);
        cur = directChild[cur];
      }
      int r = rep[cur] >= 0 ? rep[cur] : cur;
      rep[cur] = r;
      for (int x : path)
        rep[x] = r;
    }

    std::vector<std::vector<int>> parents(n_), children(n_);
    std::vector<int> head(n_, -1);
    for (int y = 0; y < n_; ++y) {
      if (!keep_[y])
        continue;
      bool isHead = true;
      for (int m : parents_[y]) {
        if (rep[m] == rep[y]) {
          isHead = false;
        } else {
          parents[rep[y]].push_back(rep[m]);
        }
      }
      if (isHead)
        head[rep[y]] = y;
    }
    for (int y = 0; y < n_; ++y) {
      if (!keep_[y])
        continue;
      if (rep[y] != y) {
        statusFlags_[rep[y]] |= statusFlags_[y];
        keep_[y] = 0;
        continue;
      }
      sortUnique(parents[y]);
      for (int m : parents[y])
        children[m].push_back(y);
      if (head[y] >= 0)
        vertexOf_[y] = vertexOf_[head[y]];
    }
    parents_ = std::move(parents);
    children_ = std::move(children);
    for (auto &c : children_)
      sortUnique(c);
  }

  // ---- vertices and their reasons (truth::genVertexReason) ----
  void buildVertices() {
    // a production vertex is the set of incoming particles in the full record
    std::map<std::vector<int>, int> vertexIds;
    vertexOf_.assign(n_, -1);
    std::vector<std::vector<int>> outgoing;
    std::vector<std::vector<int>> incoming;
    for (int i = 0; i < n_; ++i) {
      if (mothers_[i].empty())
        continue;
      std::vector<int> key = mothers_[i];
      std::sort(key.begin(), key.end());
      auto it = vertexIds.find(key);
      if (it == vertexIds.end()) {
        it = vertexIds.emplace(key, outgoing.size()).first;
        outgoing.emplace_back();
        incoming.push_back(key);
      }
      vertexOf_[i] = it->second;
      outgoing[it->second].push_back(i);
    }

    auto hadronizes = [](int pdgId) { return isShowerObject(pdgId) && std::abs(pdgId) != 6; };
    vertexReason_.assign(outgoing.size(), Unknown);
    for (size_t v = 0; v < outgoing.size(); ++v) {
      const auto &in = incoming[v];
      const auto &out = outgoing[v];
      if (in.empty() || out.empty())
        continue;
      if (std::any_of(in.begin(), in.end(), [&](int i) { return status_[i] == 4; }))
        continue;  // beam side
      auto anyOutgoingStatus = [&](int low, int high) {
        return std::any_of(out.begin(), out.end(), [&](int i) { return status_[i] >= low && status_[i] <= high; });
      };
      const bool fromShower = std::all_of(in.begin(), in.end(), [&](int i) { return hadronizes(pid_[i]); });
      if (in.size() >= 2) {
        bool flagged = std::all_of(
            in.begin(), in.end(), [&](int i) { return (statusFlags_[i] & (1u << kIsHardProcess)) != 0; });
        bool coded = std::all_of(in.begin(), in.end(), [&](int i) { return status_[i] == 21; });
        if (flagged || coded) {
          vertexReason_[v] = HardScatter;
          continue;
        }
      }
      if (fromShower && anyOutgoingStatus(41, 59)) {
        vertexReason_[v] = ShowerBranching;
        continue;
      }
      // the same without Pythia shower codes: Herwig and Sherpa give shower partons status 11
      if (fromShower &&
          std::all_of(out.begin(), out.end(), [&](int i) { return isParton(pid_[i]) && status_[i] == 11; })) {
        vertexReason_[v] = ShowerBranching;
        continue;
      }
      const bool fromString = std::any_of(in.begin(), in.end(), [&](int i) { return isStringOrCluster(pid_[i]); });
      const bool toHadron = std::any_of(out.begin(), out.end(), [&](int i) { return !isShowerObject(pid_[i]); });
      const bool toString = std::any_of(out.begin(), out.end(), [&](int i) { return isStringOrCluster(pid_[i]); });
      if (fromString || (fromShower && (toHadron || toString || anyOutgoingStatus(71, 79)))) {
        vertexReason_[v] = Hadronization;
        continue;
      }
      if (in.size() == 1 && !hadronizes(pid_[in[0]]))
        vertexReason_[v] = Decay;
    }
  }

  // ---- truth levels (TruthLevels.h), on the stored graph ----
  void dropCoveredMembers(std::vector<int> &members, bool keepDeepest) const {
    std::vector<char> covered(n_, 0);
    std::vector<int> stack;
    auto pushNeighbours = [&](int id) {
      for (int nb : keepDeepest ? parents_[id] : children_[id]) {
        if (nb != id && !covered[nb]) {
          covered[nb] = 1;
          stack.push_back(nb);
        }
      }
    };
    for (int id : members)
      pushNeighbours(id);
    while (!stack.empty()) {
      int id = stack.back();
      stack.pop_back();
      pushNeighbours(id);
    }
    members.erase(std::remove_if(members.begin(), members.end(), [&](int id) { return covered[id] != 0; }),
                  members.end());
  }

  // walk down from the seeds, stopping at a pi0 (the default reconstructablePdgIds), a generator-stable particle, or
  // a particle with nothing below it; neutrinos are dropped
  std::vector<int> reconstructableLegsFrom(const std::vector<int> &seeds) const {
    std::vector<int> legs;
    std::vector<char> seen(n_, 0);
    std::vector<int> stack;
    for (int s : seeds) {
      seen[s] = 1;
      stack.push_back(s);
    }
    while (!stack.empty()) {
      int p = stack.back();
      stack.pop_back();
      if (pid_[p] == 111 || status_[p] == 1 || children_[p].empty()) {
        int a = std::abs(pid_[p]);
        if (a != 12 && a != 14 && a != 16)
          legs.push_back(p);
        continue;
      }
      for (int c : children_[p]) {
        if (!seen[c]) {
          seen[c] = 1;
          stack.push_back(c);
        }
      }
    }
    std::sort(legs.begin(), legs.end());
    return legs;
  }

  void buildLevels() {
    levelFlags_.assign(n_, 0);
    auto stamp = [&](const std::vector<int> &members, uint32_t bit) {
      for (int i : members)
        levelFlags_[i] |= bit;
    };
    auto candidates = [&](auto pred) {
      std::vector<int> c;
      for (int i = 0; i < n_; ++i) {
        if (keep_[i] && pred(i))
          c.push_back(i);
      }
      return c;
    };

    auto hard = candidates([&](int i) { return (statusFlags_[i] & (1u << kIsHardProcess)) != 0; });
    dropCoveredMembers(hard, true);
    stamp(hard, HardProcess);
    std::vector<int> partonJets;
    for (int i : hard) {
      if (isParton(pid_[i]))
        partonJets.push_back(i);
    }
    stamp(partonJets, PartonJets);

    stamp(candidates([&](int i) { return status_[i] == 1; }), StableDecayProducts);

    auto bhad = candidates([&](int i) { return hadronHasQuark(pid_[i], 5); });
    dropCoveredMembers(bhad, true);
    stamp(bhad, BHadrons);
    auto chad = candidates([&](int i) { return hadronHasQuark(pid_[i], 4); });
    dropCoveredMembers(chad, true);
    stamp(chad, CHadrons);

    // the last tau of each radiative chain with a recorded decay, split by whether an electron or a muon is among
    // the decay products
    auto tauDecay = [&](int i) {
      if (std::abs(pid_[i]) != 15 || children_[i].empty())
        return 0;
      bool leptonic = false;
      for (int c : children_[i]) {
        int a = std::abs(pid_[c]);
        if (a == 15)
          return 0;
        if (a == 11 || a == 13)
          leptonic = true;
      }
      return leptonic ? 2 : 1;
    };
    auto tauHad = candidates([&](int i) { return tauDecay(i) == 1; });
    dropCoveredMembers(tauHad, false);
    stamp(tauHad, TauVisibleHadronic);
    auto tauLep = candidates([&](int i) { return tauDecay(i) == 2; });
    dropCoveredMembers(tauLep, false);
    stamp(tauLep, TauVisibleLeptonic);

    auto roots = candidates([&](int i) { return parents_[i].empty(); });
    auto finalState = reconstructableLegsFrom(roots);
    dropCoveredMembers(finalState, false);
    stamp(finalState, ReconstructableFinalState);
  }

  int mode_;
  int n_ = 0;
  std::vector<const GenParticle *> particles_;
  std::vector<int> pid_;
  std::vector<int> status_;
  std::unordered_map<const GenParticle *, int> index_;
  std::vector<std::vector<int>> mothers_;    // full record
  std::vector<std::vector<int>> daughters_;  // full record
  std::vector<uint16_t> statusFlags_;
  std::vector<char> keep_;
  std::vector<std::vector<int>> parents_;   // stored graph
  std::vector<std::vector<int>> children_;  // stored graph
  std::vector<int> vertexOf_;
  std::vector<int> vertexReason_;
  std::vector<uint32_t> levelFlags_;
  long eventsWithCycles_ = 0;
  long droppedCycleLinks_ = 0;
};

//------------------------------------------------------------------------------

void makeNtuples(TString inputFile,
                 TString outputFile,
                 TString jetBranch = "FatJet",
                 int genHistoryMode = GenTruthGraph::kCollapseCopies,
                 bool chargedHadronPionMass = true) {
  gSystem->Load("libDelphes");

  TFile *fout = new TFile(outputFile, "RECREATE");
  TTree *tree = new TTree("tree", "tree");

  // define branches
  std::map<TString, float> floatVars;
  floatVars["is_signal"] = 0;

  floatVars["gen_match"] = 0;
  floatVars["genpart_pt"] = 0;
  floatVars["genpart_eta"] = 0;
  floatVars["genpart_phi"] = 0;
  floatVars["genpart_pid"] = 0;

  floatVars["jet_pt"] = 0;
  floatVars["jet_eta"] = 0;
  floatVars["jet_phi"] = 0;
  floatVars["jet_energy"] = 0;
  floatVars["jet_nparticles"] = 0;
  floatVars["jet_sdmass"] = 0;
  floatVars["jet_tau1"] = 0;
  floatVars["jet_tau2"] = 0;
  floatVars["jet_tau3"] = 0;
  floatVars["jet_tau4"] = 0;

  // gen-level truth: GenFatJet (anti-kt R=0.8 on stable gen particles w/o neutrinos) matched to the reco jet
  floatVars["genjet_matched"] = 0;
  floatVars["genjet_dr"] = 0;
  floatVars["genjet_pt"] = 0;
  floatVars["genjet_eta"] = 0;
  floatVars["genjet_phi"] = 0;
  floatVars["genjet_energy"] = 0;
  floatVars["genjet_nparticles"] = 0;
  floatVars["genjet_sdmass"] = 0;
  floatVars["genjet_tau1"] = 0;
  floatVars["genjet_tau2"] = 0;
  floatVars["genjet_tau3"] = 0;
  floatVars["genjet_tau4"] = 0;
  floatVars["genjet_nhist"] = 0;

  std::map<TString, std::vector<float>> arrayVars;
  arrayVars["part_px"];
  arrayVars["part_py"];
  arrayVars["part_pz"];
  arrayVars["part_energy"];
  arrayVars["part_pt"];
  arrayVars["part_deta"];
  arrayVars["part_dphi"];
  arrayVars["part_charge"];
  arrayVars["part_pid"];
  arrayVars["part_d0val"];
  arrayVars["part_d0err"];
  arrayVars["part_dzval"];
  arrayVars["part_dzerr"];

  // constituents of the matched GenFatJet; deta/dphi are w.r.t. the reco jet axis (same frame as part_*)
  arrayVars["genjet_part_px"];
  arrayVars["genjet_part_py"];
  arrayVars["genjet_part_pz"];
  arrayVars["genjet_part_energy"];
  arrayVars["genjet_part_pt"];
  arrayVars["genjet_part_deta"];
  arrayVars["genjet_part_dphi"];
  arrayVars["genjet_part_charge"];
  arrayVars["genjet_part_pid"];

  // generator history of the matched GenFatJet (see GenTruthGraph): every constituent plus all its ancestors in the
  // CMS-style truth graph (genHistoryMode: 0 full record, 1 copy chains merged, 2 shower collapsed), ordered as in
  // the Particle branch. The graph is stored as mother->daughter edges between local indices into the genjet_hist_* arrays.
  arrayVars["genjet_hist_pt"];
  arrayVars["genjet_hist_eta"];
  arrayVars["genjet_hist_phi"];
  arrayVars["genjet_hist_mass"];
  arrayVars["genjet_hist_energy"];

  std::map<TString, std::vector<int>> intArrayVars;
  intArrayVars["genjet_hist_pid"];
  intArrayVars["genjet_hist_status"];
  intArrayVars["genjet_hist_charge"];
  intArrayVars["genjet_hist_index"];         // index in the Delphes Particle branch
  intArrayVars["genjet_hist_statusflags"];   // reco::GenStatusFlags bits, as NanoAOD GenPart_statusFlags
  intArrayVars["genjet_hist_levelflags"];    // truth::LevelFlag bits; Signal bits refer to this jet's resonance
  intArrayVars["genjet_hist_vtx"];           // local production-vertex index (shared by siblings), -1 for none
  intArrayVars["genjet_hist_vtxreason"];     // truth::VertexReason of the production vertex
  intArrayVars["genjet_hist_edge_mother"];   // local index of the mother
  intArrayVars["genjet_hist_edge_daughter"]; // local index of the daughter
  intArrayVars["genjet_part_histidx"];       // local genjet_hist_* index of each genjet_part_* entry

  // book
  for (auto &v : floatVars) {
    tree->Branch(v.first.Data(), &v.second);
  }

  for (auto &v : arrayVars) {
    tree->Branch(v.first.Data(), &v.second, /*bufsize=*/1024000);
  }

  for (auto &v : intArrayVars) {
    tree->Branch(v.first.Data(), &v.second, /*bufsize=*/1024000);
  }

  // read input
  TChain *chain = new TChain("Delphes");
  chain->Add(inputFile);
  ExRootTreeReader *treeReader = new ExRootTreeReader(chain);
  Long64_t allEntries = treeReader->GetEntries();

  std::cerr << "** Input file: " << inputFile << std::endl;
  std::cerr << "** Jet branch: " << jetBranch << std::endl;
  std::cerr << "** Total events: " << allEntries << std::endl;

  // analyze
  TClonesArray *branchParticle = treeReader->UseBranch("Particle");
  TClonesArray *branchPFCand = treeReader->UseBranch("ParticleFlowCandidate");
  TClonesArray *branchJet = treeReader->UseBranch(jetBranch);
  TClonesArray *branchGenJet = treeReader->UseBranch("GenFatJet");
  const double genJetMatchDR = 0.4;

  FatJetMatching fjmatch(0.8);
  GenTruthGraph genGraph(genHistoryMode);

  // Loop over all events
  int num_processed = 0;
  for (Long64_t entry = 0; entry < allEntries; ++entry) {
    if (entry % 1000 == 0) {
      std::cerr << "processing " << entry << " of " << allEntries << " events." << std::endl;
    }

    // Load selected branches with data from specified event
    treeReader->ReadEntry(entry);
    genGraph.build(branchParticle);

    // Loop over all jets in event
    for (Int_t i = 0; i < branchJet->GetEntriesFast(); ++i) {
      const Jet *jet = (Jet *)branchJet->At(i);

      if (jet->PT < 500 || std::abs(jet->Eta) > 2)
        continue;

      for (auto &v : floatVars) {
        v.second = 0;
      }
      for (auto &v : arrayVars) {
        v.second.clear();
      }
      for (auto &v : intArrayVars) {
        v.second.clear();
      }

      // [jcs] robustness shim for SHERPA gen-records: FatJetMatching::getLabel throws
      // std::logic_error on parton histories it cannot navigate (e.g. an unexpected decay
      // multiplicity). Upstream this is uncaught and aborts the whole file; on a 50k-event
      // SHERPA chunk that would discard the entire chunk. Catch per-jet and skip it instead
      // (same effect as the "reject un-matched jet" path below). No physics change for jets
      // that DO match. Remove this try/catch to restore the verbatim upstream behaviour.
      std::pair<FatJetMatching::FatJetLabel, const GenParticle *> label;
      try {
        label = fjmatch.getLabel(jet, branchParticle);
      } catch (const std::exception &e) {
        continue;
      }
      floatVars["gen_match"] = label.first;
      floatVars["is_signal"] = 0;

      if (fjmatch.event_type() == FatJetMatching::EventType::Top) {
        // only consider fully merged
        floatVars["is_signal"] = (label.first == FatJetMatching::Top_bcq || label.first == FatJetMatching::Top_bqq ||
                                  label.first == FatJetMatching::Top_ben || label.first == FatJetMatching::Top_bmn);
      } else if (fjmatch.event_type() == FatJetMatching::EventType::Higgs) {
        floatVars["is_signal"] = (label.first > FatJetMatching::H_all && label.first < FatJetMatching::QCD_all);
      } else if (fjmatch.event_type() == FatJetMatching::EventType::W) {
        floatVars["is_signal"] = (label.first > FatJetMatching::W_all && label.first < FatJetMatching::Z_all);
      } else if (fjmatch.event_type() == FatJetMatching::EventType::Z) {
        floatVars["is_signal"] = (label.first > FatJetMatching::Z_all && label.first < FatJetMatching::H_all);
      }

      if (fjmatch.event_type() != FatJetMatching::EventType::QCD && floatVars["is_signal"] == 0) {
        // reject un-matched jets in signal samples
        continue;
      }

      if (label.second) {
        floatVars["genpart_pt"] = label.second->PT;
        floatVars["genpart_eta"] = label.second->Eta;
        floatVars["genpart_phi"] = label.second->Phi;
        floatVars["genpart_pid"] = label.second->PID;
      }

      floatVars["jet_pt"] = jet->PT;
      floatVars["jet_eta"] = jet->Eta;
      floatVars["jet_phi"] = jet->Phi;
      floatVars["jet_energy"] = jet->P4().Energy();

      floatVars["jet_sdmass"] = jet->SoftDroppedP4[0].M();
      floatVars["jet_tau1"] = jet->Tau[0];
      floatVars["jet_tau2"] = jet->Tau[1];
      floatVars["jet_tau3"] = jet->Tau[2];
      floatVars["jet_tau4"] = jet->Tau[3];

      // Loop over all jet's constituents
      std::vector<ParticleInfo> particles;
      for (Int_t j = 0; j < jet->Constituents.GetEntriesFast(); ++j) {
        const TObject *object = jet->Constituents.At(j);

        // Check if the constituent is accessible
        if (!object)
          continue;

        if (object->IsA() == GenParticle::Class()) {
          particles.emplace_back((GenParticle *)object);
        } else if (object->IsA() == ParticleFlowCandidate::Class()) {
          particles.emplace_back((ParticleFlowCandidate *)object, chargedHadronPionMass);
        }
        const auto &p = particles.back();
        if (std::abs(p.pz) > 10000 || std::abs(p.eta) > 5 || p.pt <= 0) {
          particles.pop_back();
        }
      }

      // sort particles by pt
      std::sort(particles.begin(), particles.end(), [](const auto &a, const auto &b) { return a.pt > b.pt; });
      floatVars["jet_nparticles"] = particles.size();
      for (const auto &p : particles) {
        arrayVars["part_px"].push_back(p.px);
        arrayVars["part_py"].push_back(p.py);
        arrayVars["part_pz"].push_back(p.pz);
        arrayVars["part_energy"].push_back(p.energy);
        arrayVars["part_pt"].push_back(p.pt);
        arrayVars["part_deta"].push_back((jet->Eta > 0 ? 1 : -1) * (p.eta - jet->Eta));
        arrayVars["part_dphi"].push_back(deltaPhi(p.phi, jet->Phi));
        arrayVars["part_charge"].push_back(p.charge);
        arrayVars["part_pid"].push_back(p.pid);
        arrayVars["part_d0val"].push_back(p.d0);
        arrayVars["part_d0err"].push_back(p.d0err);
        arrayVars["part_dzval"].push_back(p.dz);
        arrayVars["part_dzerr"].push_back(p.dzerr);
      }

      // match to the closest GenFatJet within genJetMatchDR
      const Jet *genjet = nullptr;
      double genjet_dr = genJetMatchDR;
      for (Int_t k = 0; k < branchGenJet->GetEntriesFast(); ++k) {
        const Jet *gj = (Jet *)branchGenJet->At(k);
        double dr = deltaR(jet, gj);
        if (dr < genjet_dr) {
          genjet_dr = dr;
          genjet = gj;
        }
      }

      floatVars["genjet_dr"] = -1;
      if (genjet) {
        floatVars["genjet_matched"] = 1;
        floatVars["genjet_dr"] = genjet_dr;
        floatVars["genjet_pt"] = genjet->PT;
        floatVars["genjet_eta"] = genjet->Eta;
        floatVars["genjet_phi"] = genjet->Phi;
        floatVars["genjet_energy"] = genjet->P4().Energy();
        floatVars["genjet_sdmass"] = genjet->SoftDroppedP4[0].M();
        floatVars["genjet_tau1"] = genjet->Tau[0];
        floatVars["genjet_tau2"] = genjet->Tau[1];
        floatVars["genjet_tau3"] = genjet->Tau[2];
        floatVars["genjet_tau4"] = genjet->Tau[3];

        std::vector<ParticleInfo> genparticles;
        std::vector<int> genparticle_indices;
        for (Int_t j = 0; j < genjet->Constituents.GetEntriesFast(); ++j) {
          const TObject *object = genjet->Constituents.At(j);
          if (!object || object->IsA() != GenParticle::Class())
            continue;
          genparticles.emplace_back((GenParticle *)object);
          const auto &p = genparticles.back();
          if (std::abs(p.pz) > 10000 || std::abs(p.eta) > 5 || p.pt <= 0) {
            genparticles.pop_back();
          } else {
            genparticle_indices.push_back(genGraph.index((GenParticle *)object));
          }
        }

        // sort by pt, keeping the Particle-branch index aligned
        std::vector<size_t> order(genparticles.size());
        std::iota(order.begin(), order.end(), 0);
        std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return genparticles[a].pt > genparticles[b].pt; });
        {
          std::vector<ParticleInfo> sorted_particles;
          std::vector<int> sorted_indices;
          for (size_t k : order) {
            sorted_particles.push_back(genparticles[k]);
            sorted_indices.push_back(genparticle_indices[k]);
          }
          genparticles = std::move(sorted_particles);
          genparticle_indices = std::move(sorted_indices);
        }
        floatVars["genjet_nparticles"] = genparticles.size();
        for (const auto &p : genparticles) {
          arrayVars["genjet_part_px"].push_back(p.px);
          arrayVars["genjet_part_py"].push_back(p.py);
          arrayVars["genjet_part_pz"].push_back(p.pz);
          arrayVars["genjet_part_energy"].push_back(p.energy);
          arrayVars["genjet_part_pt"].push_back(p.pt);
          arrayVars["genjet_part_deta"].push_back((jet->Eta > 0 ? 1 : -1) * (p.eta - jet->Eta));
          arrayVars["genjet_part_dphi"].push_back(deltaPhi(p.phi, jet->Phi));
          arrayVars["genjet_part_charge"].push_back(p.charge);
          arrayVars["genjet_part_pid"].push_back(p.pid);
        }

        // generator history of the constituents
        auto hist = genGraph.ancestry(genparticle_indices);
        auto signal = genGraph.signalFlags(label.second ? genGraph.index(label.second) : -1);
        std::unordered_map<int, int> local;
        std::unordered_map<int, int> localVertex;
        for (size_t k = 0; k < hist.size(); ++k) {
          local[hist[k]] = k;
          const auto *gp = genGraph.particle(hist[k]);
          arrayVars["genjet_hist_pt"].push_back(gp->PT);
          arrayVars["genjet_hist_eta"].push_back(gp->Eta);
          arrayVars["genjet_hist_phi"].push_back(gp->Phi);
          arrayVars["genjet_hist_mass"].push_back(gp->P4().M());  // not gp->Mass, see ParticleInfo
          arrayVars["genjet_hist_energy"].push_back(gp->E);
          intArrayVars["genjet_hist_pid"].push_back(gp->PID);
          intArrayVars["genjet_hist_status"].push_back(gp->Status);
          intArrayVars["genjet_hist_charge"].push_back(gp->Charge);
          intArrayVars["genjet_hist_index"].push_back(hist[k]);
          intArrayVars["genjet_hist_statusflags"].push_back(genGraph.statusFlags(hist[k]));
          auto sig = signal.find(hist[k]);
          intArrayVars["genjet_hist_levelflags"].push_back(genGraph.levelFlags(hist[k]) |
                                                           (sig == signal.end() ? 0u : sig->second));
          int v = genGraph.vertex(hist[k]);
          int vlocal = -1;
          if (v >= 0) {
            vlocal = localVertex.emplace(v, localVertex.size()).first->second;
          }
          intArrayVars["genjet_hist_vtx"].push_back(vlocal);
          intArrayVars["genjet_hist_vtxreason"].push_back(genGraph.vertexReason(v));
        }
        for (size_t k = 0; k < hist.size(); ++k) {
          for (int m : genGraph.parents(hist[k])) {
            intArrayVars["genjet_hist_edge_mother"].push_back(local.at(m));
            intArrayVars["genjet_hist_edge_daughter"].push_back(k);
          }
        }
        for (int idx : genparticle_indices) {
          auto it = local.find(idx);
          intArrayVars["genjet_part_histidx"].push_back(it == local.end() ? -1 : it->second);
        }
        floatVars["genjet_nhist"] = hist.size();
      }

      tree->Fill();
      ++num_processed;
    }
  }

  tree->Write();
  std::cerr << TString::Format("** Written %d jets to output %s", num_processed, outputFile.Data()) << std::endl;
  if (genGraph.eventsWithCycles() > 0) {
    std::cerr << TString::Format("** Generator record not a DAG in %ld events: dropped %ld cyclic mother links",
                                 genGraph.eventsWithCycles(),
                                 genGraph.droppedCycleLinks())
              << std::endl;
  }

  delete treeReader;
  delete chain;
  delete fout;
}

//------------------------------------------------------------------------------
