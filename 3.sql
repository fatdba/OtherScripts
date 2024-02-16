DXP relies on mocks for CPQ, ECM, and EOC components, with the exception of JXC.

The comprehensive testing of the DXP Setup can be efficiently carried out on CCD Clusters. This suitability arises from the fact that the solution is entirely cloud-based, eliminating dependencies on external databases with MS components.

Specifically designed for ECM-EOC-DXP testing, the DXP ADP Megatar is the preferred choice.

With a capability to handle up to 25 orders per second in mixed traffic scenarios, DXP's resources allocated to the setup adhere to this operational performance standard.

In summary, the strategic use of mocks and compatibility with cloud-based environments make DXP well-suited for streamlined testing processes and optimal operational performance.


=====

From the test cases presented in the previous slide, we managed to complete only a subset, namely prepaid onboarding, additional purchase, and customer 360. The remaining test cases were excluded from the scope following discussions with DXP architects.

We opted for a customer base of 5 million since the 20 million base was not prepared for version 22.4, and we plan to explore it in the subsequent 22.5 release.


======


The absence of automated DXP installation makes the process time-consuming.

There is a lack of documentation for the mock installation/integration of DXP when the actual EOC is employed.

There is no available documentation specifying the EOC ADP components that need to be installed.

Modifications were required in the installation script to accommodate CS mock and full CPR as EOC utilizes different mocks.

====
DXP Testing extensively covers JXC and Commercial Browse.

Considerable effort was required to ensure the functionality of CS MOCK in these scenarios.

To enhance efficiency, we are seeking installation automation for swift deployment, specifically for DXP installation and the Maestro preset for ECM/EOC deployment when using DXP ADP.

Streamlining the deployment of DXP JXC bpmn becomes crucial when a full ECM/EOC is in place.

For the MVP PO, an SR loader was developed.

An issue with Additional Purchase was identified and resolved by incorporating the Payment Flag directly into the payload.
