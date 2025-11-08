# TrackX

## Overview

**TrackX** is a blockchain-based **Supply Chain Verification System** that ensures transparency, traceability, and accountability across the product lifecycle. It records every stage of a product’s journey—from manufacturing to final delivery—on an immutable ledger. Each checkpoint, validator, and certification is verified on-chain to prevent fraud and enable real-time auditing.

## Key Features

* **Immutable Product Tracking:** Each product is registered and assigned a unique identifier, with all state changes recorded on-chain.
* **Checkpoint Logging:** Enables detailed waypoint tracking, including temperature, humidity, and location data.
* **Custody Transfers:** Supports secure, auditable transitions of product ownership between parties.
* **Compliance Management:** Links certifications and compliance documents directly to product records.
* **Verifier Authorization:** Companies can designate trusted validators for data entry and compliance checks.
* **Product Recall Functionality:** Allows producers to issue recalls transparently and trace affected products.
* **Authenticity Verification:** Buyers and auditors can verify the legitimacy of products and their histories.

## Core Data Structures

* **inventory-items:** Stores all product metadata including name, description, category, source, and state.
* **waypoints:** Records each logistical checkpoint along the product’s supply route.
* **organization-validators:** Defines trusted validators per organization.
* **ownership-transitions:** Tracks custody transfers with timestamps and approval states.
* **compliance-documents:** Stores certificates and compliance proofs for regulated products.
* **next-item-id, next-waypoint-id, next-transition-id:** Maintain unique ID counters for consistent record keeping.

## Major Functions

### Product Lifecycle

* **`register-inventory-item`** – Creates a new product record with metadata and initializes its supply tracking.
* **`add-waypoint`** – Logs a checkpoint (e.g., manufacturing, customs, warehouse, retail) with validation and sensor data.
* **`recall-inventory-item`** – Marks a product as recalled and adds a recall checkpoint.

### Custody Management

* **`initiate-transition`** – Begins transfer of product custody between two parties.
* **`accept-transition`** – Accepts and finalizes a pending product transfer.
* **`reject-transition` / `cancel-transition`** – Handles transfer rejections or cancellations.

### Compliance and Verification

* **`add-compliance-document`** – Attaches regulatory or quality certificates to a product.
* **`revoke-compliance-document`** – Revokes an existing certification.
* **`is-document-valid`** – Verifies if a certification is still valid based on expiration and status.

### Verifier Management

* **`authorize-validator`** – Grants a user validation privileges for an organization.
* **`revoke-validator`** – Removes validation rights from a user.

### Delivery and Logistics

* **`set-delivery-details`** – Assigns final delivery destination and expected arrival block height.
* **`verify-item-authenticity`** – Confirms product legitimacy and status.

### Read-Only Queries

* **`get-item-details`** – Retrieves full product metadata.
* **`get-waypoint`**, **`get-transition`**, **`get-compliance-document`** – Access detailed record data by ID.

## Error Handling

The contract includes structured assertions for:

* Unauthorized access attempts
* Invalid product or transition IDs
* Recalled or expired product operations
* Unauthorized certification or transfer actions

## Summary

TrackX builds a trusted digital supply chain using Clarity smart contracts. It bridges manufacturers, logistics partners, regulators, and consumers on a single transparent system, ensuring **product integrity, compliance, and verifiable provenance** from origin to destination.
