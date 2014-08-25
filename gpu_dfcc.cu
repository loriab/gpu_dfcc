#include <libplugin/plugin.h>
#include <psi4-dec.h>
#include <libparallel/parallel.h>
#include <liboptions/liboptions.h>
#include <libmints/mints.h>
#include <libpsio/psio.hpp>
#include <../bin/fnocc/ccsd.h>
#include <../bin/fnocc/frozen_natural_orbitals.h>
#include "ccsd.h"

INIT_PLUGIN

using namespace boost;

namespace psi{ namespace fnocc {

extern "C" 
int read_options(std::string name, Options& options)
{
    if (name == "GPU_DFCC"|| options.read_globals()) {
      /*- Do dgemm timings? ! expert -*/
      options.add_bool("DGEMM_TIMINGS",false);
      /*- Maximum amount of pinned CPU memory (mb) -*/
      options.add_int("MAX_MAPPED_MEMORY",7000);
      /*- Override number of GPUs detected? -*/
      options.add_int("NUM_GPUS",0);
      /*- Do time each cc diagram? -*/
      options.add_bool("CC_TIMINGS",false);
      /*- Convergence for the CC energy.  Note that convergence is
          met only when E_CONVERGENCE and R_CONVERGENCE are satisfied. -*/
      options.add_double("E_CONVERGENCE", 1.0e-8);
      /*- Convergence for the CC amplitudes.  Note that convergence is
          met only when E_CONVERGENCE and R_CONVERGENCE are satisfied. -*/
      options.add_double("R_CONVERGENCE", 1.0e-7);
      /*- Maximum number of CC iterations -*/
      options.add_int("MAXITER", 100);
      /*- Desired number of DIIS vectors -*/
      options.add_int("DIIS_MAX_VECS", 8);
      /*- Do use low memory option for triples contribution? Note that this 
          option is enabled automatically if the memory requirements of the 
          conventional algorithm would exceed the available resources -*/
      //options.add_bool("TRIPLES_LOW_MEMORY",false);
      /*- Do compute triples contribution? !expert -*/
      options.add_bool("COMPUTE_TRIPLES", true);
      /*- Do use MP2 NOs to truncate virtual space for CCSD and (T)? -*/
      options.add_bool("NAT_ORBS", false);
      /*- Cutoff for occupation of MP2 NO orbitals in FNO-CCSD(T)
          ( only valid if |gpu_dfcc__nat_orbs| = true ) -*/
      options.add_double("OCC_TOLERANCE", 1.0e-6);
      /*- Do SCS-MP2? -*/
      options.add_bool("SCS_MP2", false);
      /*- Do SCS-CCSD? -*/
      options.add_bool("SCS_CCSD", false);
      /*- Do SCS-CEPA? Note that the scaling factors will be identical
      to those for SCS-CCSD. -*/
      options.add_bool("SCS_CEPA", false);
      /*- Opposite-spin scaling factor for SCS-MP2 -*/
      options.add_double("MP2_SCALE_OS",1.20);
      /*- Same-spin scaling factor for SCS-MP2 -*/
      options.add_double("MP2_SCALE_SS",1.0/3.0);
      /*- Oppposite-spin scaling factor for SCS-CCSD -*/
      options.add_double("CC_SCALE_OS", 1.27);
      /*- Same-spin scaling factor for SCS-CCSD -*/
      options.add_double("CC_SCALE_SS",1.13);

      /*- Do use density fitting in CC? This keyword is used internally
          by the driver. Changing its value will have no effect on the 
          computation. ! expert -*/
      options.add_bool("DFCC",false);
      /*- Auxilliary basis for df-ccsd(t). -*/
      options.add_str("DF_BASIS_CC","");
      /*- Tolerance for Cholesky decomposition of the ERI tensor. 
          ( only valid if |gpu_dfcc__df_basis_cc| = cholesky or 
          |scf__scf_type|=cd -*/
      options.add_double("CHOLESKY_TOLERANCE",1.0e-4);

      /*- Is this a CEPA job? This parameter is used internally
      by the pythond driver.  Changing its value won't have any
      effect on the procedure. !expert -*/
      options.add_bool("RUN_CEPA",false);
      /*- Which coupled-pair method is called?  This parameter is
      used internally by the python driver.  Changing its value
      won't have any effect on the procedure. !expert -*/
      options.add_str("CEPA_LEVEL","CEPA(0)");
      /*- Compute the dipole moment? Note that dipole moments
      are only available in the FNOCC module for the ACPF, 
      AQCC, CISD, and CEPA(0) methods. -*/
      options.add_bool("DIPMOM",false);
      /*- Flag to exclude singly excited configurations from a 
      coupled-pair computation.  -*/
      options.add_bool("CEPA_NO_SINGLES",false);

    }

    return true;
}

extern "C" 
PsiReturnType gpu_dfcc(Options& options)
{
    boost::shared_ptr<Wavefunction> wfn;
    boost::shared_ptr<DFFrozenNO> fno(new DFFrozenNO(Process::environment.wavefunction(),options));
    fno->ThreeIndexIntegrals();
    if ( options.get_bool("NAT_ORBS") ) {
        fno->ComputeNaturalOrbitals();
        wfn = (boost::shared_ptr<Wavefunction>)fno;
    }else {
        wfn = Process::environment.wavefunction();
    }
    boost::shared_ptr<GPUDFCoupledCluster> ccsd (new GPUDFCoupledCluster(wfn,options));
    ccsd->compute_energy();

    return Success;
}

}} // End namespaces
