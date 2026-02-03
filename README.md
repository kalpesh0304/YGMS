# ONGC-CST-Purchase-Date-Sharing-

## YGMS - Gas Sale and Purchase Management System

This repository contains SAP ABAP code for the ONGC CST (Central Sales Tax) Purchase Data Sharing System.

## Overview

The system facilitates data sharing between ONGC (Oil and Natural Gas Corporation) and GAIL for CST purchase transactions, enabling:

- Purchase data management and validation
- CST allocation processing
- B2B transaction handling
- Audit logging and tracking
- Email notifications

## Repository Structure

```
src/
├── ygms_cst_purchase_main.prog.abap    # Main program
├── ygms_cl_cst_controller.clas.abap    # Controller class
├── ygms_cl_cst_data_handler.clas.abap  # Data handler
├── ygms_cl_cst_validator.clas.abap     # Validation logic
├── ygms_cl_cst_allocator.clas.abap     # Allocation processor
├── ygms_cl_cst_audit_handler.clas.abap # Audit logging
├── ygms_cl_cst_email_sender.clas.abap  # Email notifications
├── ygms_cx_cst_*.clas.abap             # Exception classes
├── ygms_if_cst_*.intf.abap             # Interfaces
├── ygms_cst_*.tabl.xml                 # Database tables
├── ygms_de_*.dtel.xml                  # Data elements
├── ygms_*.doma.xml                     # Domains
└── ygms_tt_*.ttyp.xml                  # Table types
```

## Documentation

- `FSD_ONGC_CST_Purchase_Data_Sharing_V1_2.docx` - Functional Specification Document
- `TSD_ONGC_CST_Purchase_Data_Sharing_V1_3.docx` - Technical Specification Document
- `Claude_Code_Prompt_ONGC_CST_Purchase_V1_2.md` - Development prompt

## Installation

This project uses abapGit for version control. Import using the `.abapgit.xml` configuration file.

## License

Proprietary - ONGC/GAIL
