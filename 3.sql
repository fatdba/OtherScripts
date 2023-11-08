CREATE SCHEMA public AUTHORIZATION postgres;

-- DROP SEQUENCE public.acct_role_seq;

CREATE SEQUENCE public.acct_role_seq
    INCREMENT BY 50
    MINVALUE 1
    MAXVALUE 9223372036854775807
    START 1001
    CACHE 1
    NO CYCLE;
-- DROP SEQUENCE public.addr_seq;

CREATE SEQUENCE public.addr_seq
    INCREMENT BY 50
    MINVALUE 1
    MAXVALUE 9223372036854775807
    START 1001
    CACHE 1
    NO CYCLE;
-- DROP SEQUENCE public.cont_meth_seq;

CREATE SEQUENCE public.cont_meth_seq
    INCREMENT BY 50
    MINVALUE 1
    MAXVALUE 9223372036854775807
    START 1001
    CACHE 1
    NO CYCLE;
-- DROP SEQUENCE public.ext_key_seq;

CREATE SEQUENCE public.ext_key_seq
    INCREMENT BY 50
    MINVALUE 1
    MAXVALUE 9223372036854775807
    START 1001
    CACHE 1
    NO CYCLE;
-- DROP SEQUENCE public.fatca_seq;

CREATE SEQUENCE public.fatca_seq
    INCREMENT BY 50
    MINVALUE 1
    MAXVALUE 9223372036854775807
    START 1001
    CACHE 1
    NO CYCLE;
-- DROP SEQUENCE public.ident_seq;

CREATE SEQUENCE public.ident_seq
    INCREMENT BY 50
    MINVALUE 1
    MAXVALUE 9223372036854775807
    START 1001
    CACHE 1
    NO CYCLE;
-- DROP SEQUENCE public.tax_seq;

CREATE SEQUENCE public.tax_seq
    INCREMENT BY 50
    MINVALUE 1
    MAXVALUE 9223372036854775807
    START 1001
    CACHE 1
    NO CYCLE;-- public.account_role_type_ref definition

-- Drop table

-- DROP TABLE account_role_type_ref;

CREATE TABLE account_role_type_ref (
    account_role_type_code int8 NOT NULL,
    account_role_type_desc varchar(255) NULL,
    account_role_type_name varchar(255) NOT NULL,
    CONSTRAINT account_role_type_ref_pkey PRIMARY KEY (account_role_type_code),
    CONSTRAINT uk_da1v8lojily3j8b3nuhejs8eg UNIQUE (account_role_type_name)
);


-- public.address_type_ref definition

-- Drop table

-- DROP TABLE address_type_ref;

CREATE TABLE address_type_ref (
    address_type_code int8 NOT NULL,
    address_type_desc varchar(255) NULL,
    address_type_name varchar(255) NOT NULL,
    CONSTRAINT address_type_ref_pkey PRIMARY KEY (address_type_code),
    CONSTRAINT uk_ao8xm10mw8q7lqmdskd1y049v UNIQUE (address_type_name)
);


-- public.contact_method_ref definition

-- Drop table

-- DROP TABLE contact_method_ref;

CREATE TABLE contact_method_ref (
    contact_method_code int8 NOT NULL,
    contact_method_desc varchar(255) NULL,
    contact_method_name varchar(255) NOT NULL,
    CONSTRAINT contact_method_ref_pkey PRIMARY KEY (contact_method_code),
    CONSTRAINT uk_f53rt8krmhbcrroyf3cnffosy UNIQUE (contact_method_name)
);


-- public.country_ref definition

-- Drop table

-- DROP TABLE country_ref;

CREATE TABLE country_ref (
    country_code int8 NOT NULL,
    country_desc varchar(255) NULL,
    country_iso_code varchar(255) NULL,
    country_name varchar(255) NOT NULL,
    CONSTRAINT country_ref_pkey PRIMARY KEY (country_code),
    CONSTRAINT uk_ldcgqka5xoprg96mxfywlvtkw UNIQUE (country_name)
);


-- public.fatca_status_ref definition

-- Drop table

-- DROP TABLE fatca_status_ref;

CREATE TABLE fatca_status_ref (
    fatca_status_code int8 NOT NULL,
    fatca_status_desc varchar(255) NULL,
    fatca_status_name varchar(255) NOT NULL,
    CONSTRAINT fatca_status_ref_pkey PRIMARY KEY (fatca_status_code),
    CONSTRAINT uk_t1g82q5xolqjgt5k96wjp9rij UNIQUE (fatca_status_name)
);


-- public.generation_ref definition

-- Drop table

-- DROP TABLE generation_ref;

CREATE TABLE generation_ref (
    generation_code int8 NOT NULL,
    generation_desc varchar(255) NULL,
    generation_name varchar(255) NOT NULL,
    CONSTRAINT generation_ref_pkey PRIMARY KEY (generation_code),
    CONSTRAINT uk_h5qtwq23u2m92wol9jmkwth2t UNIQUE (generation_name)
);


-- public.identifier_ref definition

-- Drop table

-- DROP TABLE identifier_ref;

CREATE TABLE identifier_ref (
    identifier_code int8 NOT NULL,
    identifier_desc varchar(255) NULL,
    identifier_name varchar(255) NOT NULL,
    CONSTRAINT identifier_ref_pkey PRIMARY KEY (identifier_code),
    CONSTRAINT uk_djxylyqbhq8r9cjv25rsunc7u UNIQUE (identifier_name)
);


-- public.key_metadata definition

-- Drop table

-- DROP TABLE key_metadata;

CREATE TABLE key_metadata (
    id varchar(36) NOT NULL,
    data_key varchar(1024) NULL,
    data_type varchar(255) NULL,
    encrypted_array bool NOT NULL,
    encryption_type int4 NULL,
    key_name varchar(255) NULL,
    key_version int4 NULL,
    protected_value varchar(255) NULL,
    secret_path varchar(255) NULL,
    secret_version int4 NULL,
    tokenization_type varchar(255) NULL,
    tweak_value varchar(255) NULL,
    tweak_version int4 NULL,
    CONSTRAINT key_metadata_pkey PRIMARY KEY (id),
    CONSTRAINT key_metadata_tokenization_type_check CHECK (((tokenization_type)::text = ANY ((ARRAY['UNBOUND'::character varying, 'ROT13'::character varying, 'PASSTHROUGH'::character varying, 'ENVELOPE_ENCRYPTION'::character varying])::text[])))
);


-- public.legacy_account_file_type_ref definition

-- Drop table

-- DROP TABLE legacy_account_file_type_ref;

CREATE TABLE legacy_account_file_type_ref (
    legacy_account_file_type_code int8 NOT NULL,
    legacy_account_file_type_desc varchar(255) NULL,
    legacy_account_file_type_name varchar(255) NOT NULL,
    CONSTRAINT legacy_account_file_type_ref_pkey PRIMARY KEY (legacy_account_file_type_code),
    CONSTRAINT uk_at0plw438yvgf6wa9emmwcllc UNIQUE (legacy_account_file_type_name)
);


-- public.lob_ref definition

-- Drop table

-- DROP TABLE lob_ref;

CREATE TABLE lob_ref (
    lob_code int8 NOT NULL,
    lob_desc varchar(255) NULL,
    lob_name varchar(255) NOT NULL,
    CONSTRAINT lob_ref_pkey PRIMARY KEY (lob_code),
    CONSTRAINT uk_enyjuf2nfhahqeapbg4opeurs UNIQUE (lob_name)
);


-- public.naics_ref definition

-- Drop table

-- DROP TABLE naics_ref;

CREATE TABLE naics_ref (
    naics_code int8 NOT NULL,
    naics_desc varchar(255) NULL,
    naics_name varchar(255) NOT NULL,
    CONSTRAINT naics_ref_pkey PRIMARY KEY (naics_code),
    CONSTRAINT uk_r93oprc0avya4uoxsgx0xmyik UNIQUE (naics_name)
);


-- public.org_type_ref definition

-- Drop table

-- DROP TABLE org_type_ref;

CREATE TABLE org_type_ref (
    org_type_code int8 NOT NULL,
    org_type_desc varchar(255) NULL,
    org_type_name varchar(255) NOT NULL,
    CONSTRAINT org_type_ref_pkey PRIMARY KEY (org_type_code),
    CONSTRAINT uk_ow5i5ygn642jb5v5tcvqar4mn UNIQUE (org_type_name)
);


-- public.party_status_ref definition

-- Drop table

-- DROP TABLE party_status_ref;

CREATE TABLE party_status_ref (
    party_status_code int8 NOT NULL,
    party_status_desc varchar(255) NULL,
    party_status_name varchar(255) NOT NULL,
    CONSTRAINT party_status_ref_pkey PRIMARY KEY (party_status_code),
    CONSTRAINT uk_aybxmf3qvlp56wona44lr3ljl UNIQUE (party_status_name)
);


-- public.prefix_ref definition

-- Drop table

-- DROP TABLE prefix_ref;

CREATE TABLE prefix_ref (
    prefix_code int8 NOT NULL,
    prefix_desc varchar(255) NULL,
    prefix_name varchar(255) NOT NULL,
    CONSTRAINT prefix_ref_pkey PRIMARY KEY (prefix_code),
    CONSTRAINT uk_c9r2mqutvctlujfypm3dda6hq UNIQUE (prefix_name)
);


-- public.product definition

-- Drop table

-- DROP TABLE product;

CREATE TABLE product (
    product_id varchar(255) NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    product_name varchar(255) NULL,
    product_type varchar(255) NULL,
    CONSTRAINT product_pkey PRIMARY KEY (product_id)
);


-- public.residence_ref definition

-- Drop table

-- DROP TABLE residence_ref;

CREATE TABLE residence_ref (
    residence_code int8 NOT NULL,
    residence_desc varchar(255) NULL,
    residence_name varchar(255) NOT NULL,
    CONSTRAINT residence_ref_pkey PRIMARY KEY (residence_code),
    CONSTRAINT uk_gvqfkxb3nm7u61gbga2k543wt UNIQUE (residence_name)
);


-- public.source_system_ref definition

-- Drop table

-- DROP TABLE source_system_ref;

CREATE TABLE source_system_ref (
    source_system_code int8 NOT NULL,
    source_system_desc varchar(255) NULL,
    source_system_name varchar(255) NOT NULL,
    CONSTRAINT source_system_ref_pkey PRIMARY KEY (source_system_code),
    CONSTRAINT uk_h4ddxaqnkfmi8d2uf41ahhe89 UNIQUE (source_system_name)
);


-- public.state_province_ref definition

-- Drop table

-- DROP TABLE state_province_ref;

CREATE TABLE state_province_ref (
    state_province_code int8 NOT NULL,
    state_province_desc varchar(255) NULL,
    state_province_name varchar(255) NOT NULL,
    CONSTRAINT state_province_ref_pkey PRIMARY KEY (state_province_code),
    CONSTRAINT uk_mc5kpgnpvm27y1715t66pbtaw UNIQUE (state_province_name)
);


-- public.tax_classification_ref definition

-- Drop table

-- DROP TABLE tax_classification_ref;

CREATE TABLE tax_classification_ref (
    tax_classification_code int8 NOT NULL,
    tax_classification_desc varchar(255) NULL,
    tax_classification_name varchar(255) NOT NULL,
    CONSTRAINT tax_classification_ref_pkey PRIMARY KEY (tax_classification_code),
    CONSTRAINT uk_7al3fqqsomlgysnsxffniwr48 UNIQUE (tax_classification_name)
);


-- public.tax_country_ref definition

-- Drop table

-- DROP TABLE tax_country_ref;

CREATE TABLE tax_country_ref (
    tax_country_code int8 NOT NULL,
    tax_country_desc varchar(255) NULL,
    tax_country_name varchar(255) NOT NULL,
    CONSTRAINT tax_country_ref_pkey PRIMARY KEY (tax_country_code),
    CONSTRAINT uk_skug1j3y5ok4stlmd6do4p2b3 UNIQUE (tax_country_name)
);


-- public.tax_document_ref definition

-- Drop table

-- DROP TABLE tax_document_ref;

CREATE TABLE tax_document_ref (
    tax_document_code int8 NOT NULL,
    tax_document_desc varchar(255) NULL,
    tax_document_name varchar(255) NOT NULL,
    CONSTRAINT tax_document_ref_pkey PRIMARY KEY (tax_document_code),
    CONSTRAINT uk_5kmld79cd6jm4s8ktmqaqhldl UNIQUE (tax_document_name)
);


-- public.tax_withholding_ref definition

-- Drop table

-- DROP TABLE tax_withholding_ref;

CREATE TABLE tax_withholding_ref (
    tax_withholding_code int8 NOT NULL,
    tax_withholding_desc varchar(255) NULL,
    tax_withholding_name varchar(255) NOT NULL,
    CONSTRAINT tax_withholding_ref_pkey PRIMARY KEY (tax_withholding_code),
    CONSTRAINT uk_4xarrxj5x7rt6bp882bkx9jyn UNIQUE (tax_withholding_name)
);


-- public.user_party_relationship definition

-- Drop table

-- DROP TABLE user_party_relationship;

CREATE TABLE user_party_relationship (
    party_domain_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    last_update_date timestamp(6) NULL,
    role_type int4 NULL,
    CONSTRAINT user_party_relationship_pkey PRIMARY KEY (party_domain_id, user_id)
);


-- public.users definition

-- Drop table

-- DROP TABLE users;

CREATE TABLE users (
    user_id uuid NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    last_update_date timestamp(6) NULL,
    CONSTRAINT users_pkey PRIMARY KEY (user_id)
);


-- public.account definition

-- Drop table

-- DROP TABLE account;

CREATE TABLE account (
    account_id varchar(255) NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    account_number varchar(255) NULL,
    account_numberuuid varchar(255) NULL,
    account_type varchar(255) NULL,
    legacy_account_file_type_code int8 NOT NULL,
    CONSTRAINT account_pkey PRIMARY KEY (account_id),
    CONSTRAINT fk63is0mi3al0lj0wqep7ghrq83 FOREIGN KEY (legacy_account_file_type_code) REFERENCES legacy_account_file_type_ref(legacy_account_file_type_code)
);


-- public.account_key_metadata definition

-- Drop table

-- DROP TABLE account_key_metadata;

CREATE TABLE account_key_metadata (
    account_account_id varchar(255) NOT NULL,
    key_metadata_id varchar(36) NOT NULL,
    property_name varchar(255) NOT NULL,
    CONSTRAINT account_key_metadata_pkey PRIMARY KEY (account_account_id, property_name),
    CONSTRAINT uk_t1sro9lo6e0qan6sjcl5idv0f UNIQUE (key_metadata_id),
    CONSTRAINT fkgbekfhy2h9d652vv3a73ghrpb FOREIGN KEY (key_metadata_id) REFERENCES key_metadata(id),
    CONSTRAINT fki2q4g3fqhdwej77b81aq4l2x7 FOREIGN KEY (account_account_id) REFERENCES account(account_id)
);


-- public.account_role definition

-- Drop table

-- DROP TABLE account_role;

CREATE TABLE account_role (
    account_role_id int8 NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    account_numberuuid varchar(255) NOT NULL,
    last_update_date timestamp(6) NULL,
    party_domain_id varchar(255) NOT NULL,
    start_date timestamp(6) NULL,
    account_role_type_code int8 NOT NULL,
    legacy_account_file_type_code int8 NOT NULL,
    CONSTRAINT account_role_pkey PRIMARY KEY (account_role_id),
    CONSTRAINT fk2xdejv42c4hsm84lbo6gcq5h2 FOREIGN KEY (legacy_account_file_type_code) REFERENCES legacy_account_file_type_ref(legacy_account_file_type_code),
    CONSTRAINT fkjra48tdt1ep2u6wwk507pr3rr FOREIGN KEY (account_role_type_code) REFERENCES account_role_type_ref(account_role_type_code)
);


-- public.party definition

-- Drop table

-- DROP TABLE party;

CREATE TABLE party (
    party_domain_id varchar(255) NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    last_update_date timestamp(6) NOT NULL,
    party_type bpchar(1) NOT NULL,
    residency_status varchar(255) NULL,
    since_date timestamp(6) NULL,
    lob_code int8 NULL,
    party_status_code int8 NOT NULL,
    CONSTRAINT party_pkey PRIMARY KEY (party_domain_id),
    CONSTRAINT fk5hk0l8lilm7r1ch0uljk3w9cq FOREIGN KEY (party_status_code) REFERENCES party_status_ref(party_status_code),
    CONSTRAINT fkdjm685c29i67fg13gyxugnq25 FOREIGN KEY (lob_code) REFERENCES lob_ref(lob_code)
);


-- public.person definition

-- Drop table

-- DROP TABLE person;

CREATE TABLE person (
    party_domain_id varchar(255) NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    birth_date timestamp(6) NULL,
    deceased_date timestamp(6) NULL,
    ein varchar(255) NULL,
    last_update_date timestamp(6) NOT NULL,
    name_first varchar(255) NULL,
    name_last varchar(255) NOT NULL,
    name_middle_one varchar(255) NULL,
    name_middle_three varchar(255) NULL,
    name_middle_two varchar(255) NULL,
    name_suffix varchar(255) NULL,
    ssn varchar(255) NULL,
    ssnuuid varchar(255) NULL,
    generation_code int8 NULL,
    prefix_code int8 NULL,
    CONSTRAINT person_pkey PRIMARY KEY (party_domain_id),
    CONSTRAINT fkj1g5c1a0oxobimru0smnh3geb FOREIGN KEY (party_domain_id) REFERENCES party(party_domain_id),
    CONSTRAINT fkkp8mj8w7x29d62nde1wss4gdp FOREIGN KEY (generation_code) REFERENCES generation_ref(generation_code),
    CONSTRAINT fko5ew257utqagxuu9st2oix0jj FOREIGN KEY (prefix_code) REFERENCES prefix_ref(prefix_code)
);


-- public.person_key_metadata definition

-- Drop table

-- DROP TABLE person_key_metadata;

CREATE TABLE person_key_metadata (
    person_party_domain_id varchar(255) NOT NULL,
    key_metadata_id varchar(36) NOT NULL,
    property_name varchar(255) NOT NULL,
    CONSTRAINT person_key_metadata_pkey PRIMARY KEY (person_party_domain_id, property_name),
    CONSTRAINT uk_f4wvxwcffeln5i5gr05e68n7s UNIQUE (key_metadata_id),
    CONSTRAINT fkbgj1wip0yu9tokmi6ievhy0au FOREIGN KEY (person_party_domain_id) REFERENCES person(party_domain_id),
    CONSTRAINT fkfbv7fyfxlb7hsaokw9yio8k3v FOREIGN KEY (key_metadata_id) REFERENCES key_metadata(id)
);


-- public.tax definition

-- Drop table

-- DROP TABLE tax;

CREATE TABLE tax (
    tax_data_id int8 NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    party_domain_id varchar(255) NULL,
    tax_country_date timestamp(6) NULL,
    tax_withholding_date timestamp(6) NULL,
    tax_classification_code int8 NULL,
    tax_country_code int8 NULL,
    tax_withholding_code int8 NULL,
    CONSTRAINT tax_pkey PRIMARY KEY (tax_data_id),
    CONSTRAINT fk2uc5xpmkvtdn7uugbx5rjwsv8 FOREIGN KEY (party_domain_id) REFERENCES party(party_domain_id),
    CONSTRAINT fkk0sj30rcj68n1p2bw0ocor40a FOREIGN KEY (tax_classification_code) REFERENCES tax_classification_ref(tax_classification_code),
    CONSTRAINT fkmcjemo5vwygp3y409ffxo2us6 FOREIGN KEY (tax_country_code) REFERENCES tax_country_ref(tax_country_code),
    CONSTRAINT fkmpl5jylsmoafifdhwnq3lms08 FOREIGN KEY (tax_withholding_code) REFERENCES tax_withholding_ref(tax_withholding_code)
);


-- public.address definition

-- Drop table

-- DROP TABLE address;

CREATE TABLE address (
    address_id int8 NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    address_line_one varchar(255) NOT NULL,
    address_line_three varchar(255) NULL,
    address_line_two varchar(255) NULL,
    address_validation varchar(255) NULL,
    city varchar(255) NOT NULL,
    last_update_date timestamp(6) NOT NULL,
    party_domain_id varchar(255) NULL,
    region varchar(255) NULL,
    residence_number varchar(255) NULL,
    src_address_id int8 NOT NULL,
    zip_code varchar(255) NULL,
    address_type_code int8 NOT NULL,
    country_code int8 NULL,
    residence_code int8 NULL,
    state_province_code int8 NULL,
    CONSTRAINT address_pkey PRIMARY KEY (address_id),
    CONSTRAINT fk3obpvqycivyaq0paru04o20wk FOREIGN KEY (state_province_code) REFERENCES state_province_ref(state_province_code),
    CONSTRAINT fk75u3pj111vuj4bqr4vj9a95fw FOREIGN KEY (country_code) REFERENCES country_ref(country_code),
    CONSTRAINT fka95115trulsy6ogwrrcvao2v8 FOREIGN KEY (address_type_code) REFERENCES address_type_ref(address_type_code),
    CONSTRAINT fkrg7uo1gkktktte98crtfakw0e FOREIGN KEY (residence_code) REFERENCES residence_ref(residence_code),
    CONSTRAINT fksibmyfd1hdmf4y3fb7dw0whr FOREIGN KEY (party_domain_id) REFERENCES party(party_domain_id)
);


-- public.contact_method definition

-- Drop table

-- DROP TABLE contact_method;

CREATE TABLE contact_method (
    contact_method_id int8 NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    contact_method_value varchar(255) NOT NULL,
    party_domain_id varchar(255) NULL,
    preferred_indicator bpchar(1) NULL,
    src_contact_method_id int8 NOT NULL,
    contact_method_code int8 NOT NULL,
    CONSTRAINT contact_method_pkey PRIMARY KEY (contact_method_id),
    CONSTRAINT fk3q4e8x7g2182gp6sday7ie5ur FOREIGN KEY (contact_method_code) REFERENCES contact_method_ref(contact_method_code),
    CONSTRAINT fkhqota4w58qw0pwd7124bolnvh FOREIGN KEY (party_domain_id) REFERENCES party(party_domain_id)
);


-- public.external_key definition

-- Drop table

-- DROP TABLE external_key;

CREATE TABLE external_key (
    external_key_id int8 NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    party_domain_id varchar(255) NULL,
    source_system_key varchar(255) NOT NULL,
    source_system int8 NOT NULL,
    CONSTRAINT external_key_pkey PRIMARY KEY (external_key_id),
    CONSTRAINT fk2b2tx9lrergcbx1lsv5umkvye FOREIGN KEY (source_system) REFERENCES source_system_ref(source_system_code),
    CONSTRAINT fkj8igg0u788ybxnb7sb9fh75f2 FOREIGN KEY (party_domain_id) REFERENCES party(party_domain_id)
);


-- public.fatca definition

-- Drop table

-- DROP TABLE fatca;

CREATE TABLE fatca (
    fatca_id int8 NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    fatca_country varchar(255) NULL,
    giin_validation_date timestamp(6) NULL,
    party_domain_id varchar(255) NULL,
    received_date timestamp(6) NULL,
    reviewed_date timestamp(6) NULL,
    tax_form_sign_date timestamp(6) NULL,
    tax_form_version varchar(255) NULL,
    fatca_status_code int8 NULL,
    tax_document_code int8 NOT NULL,
    CONSTRAINT fatca_pkey PRIMARY KEY (fatca_id),
    CONSTRAINT fkjq1r1vjvm5vytkgrsnbmx3r00 FOREIGN KEY (tax_document_code) REFERENCES tax_document_ref(tax_document_code),
    CONSTRAINT fkrido6tawgmmkm65gv4go4dsw3 FOREIGN KEY (party_domain_id) REFERENCES party(party_domain_id),
    CONSTRAINT fkv9lbsq6jxpxepevpkug72k3w FOREIGN KEY (fatca_status_code) REFERENCES fatca_status_ref(fatca_status_code)
);


-- public.identifier definition

-- Drop table

-- DROP TABLE identifier;

CREATE TABLE identifier (
    identifier_id int8 NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    expiry_date timestamp(6) NULL,
    identifier_value varchar(255) NOT NULL,
    identifier_valueuuid varchar(255) NULL,
    issue_date timestamp(6) NULL,
    issue_location varchar(255) NULL,
    party_domain_id varchar(255) NULL,
    identifier_code int8 NOT NULL,
    CONSTRAINT identifier_pkey PRIMARY KEY (identifier_id),
    CONSTRAINT fk8p2vbjrnt8a3uephoh98agy4c FOREIGN KEY (party_domain_id) REFERENCES party(party_domain_id),
    CONSTRAINT fkd6v66ndke8xa3namvykqqg52w FOREIGN KEY (identifier_code) REFERENCES identifier_ref(identifier_code)
);


-- public.identifier_key_metadata definition

-- Drop table

-- DROP TABLE identifier_key_metadata;

CREATE TABLE identifier_key_metadata (
    identifier_identifier_id int8 NOT NULL,
    key_metadata_id varchar(36) NOT NULL,
    property_name varchar(255) NOT NULL,
    CONSTRAINT identifier_key_metadata_pkey PRIMARY KEY (identifier_identifier_id, property_name),
    CONSTRAINT uk_cklu7hg3dyx6coqsxqcymhrg2 UNIQUE (key_metadata_id),
    CONSTRAINT fk2hk2xsnutnxtpiqdcqey0w359 FOREIGN KEY (identifier_identifier_id) REFERENCES identifier(identifier_id),
    CONSTRAINT fkfe9ejf4mxws9wpk8uwhygmmjs FOREIGN KEY (key_metadata_id) REFERENCES key_metadata(id)
);


-- public.org definition

-- Drop table

-- DROP TABLE org;

CREATE TABLE org (
    party_domain_id varchar(255) NOT NULL,
    created_date timestamp(6) NOT NULL,
    last_modified_date timestamp(6) NOT NULL,
    established_date timestamp(6) NULL,
    last_update_date timestamp(6) NOT NULL,
    non_profit_indicator bpchar(1) NULL,
    org_name varchar(255) NOT NULL,
    tin varchar(255) NULL,
    org_type_code int8 NOT NULL,
    naics_code int8 NULL,
    CONSTRAINT org_pkey PRIMARY KEY (party_domain_id),
    CONSTRAINT fk1xfjl2cou0yiiswuc7j6coc01 FOREIGN KEY (naics_code) REFERENCES naics_ref(naics_code),
    CONSTRAINT fkhvo4axvafn3oo702qpuf7idg2 FOREIGN KEY (org_type_code) REFERENCES org_type_ref(org_type_code),
    CONSTRAINT fkjqyf01d5i0bbg3ypfbu2j3a6c FOREIGN KEY (party_domain_id) REFERENCES party(party_domain_id)
);
