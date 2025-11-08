;; Supply Chain Verification System
;; Enables tracking of products through the supply chain with
;; immutable records and verification at each step of the process

;; Product definitions
(define-map product-registry
  { product-id: uint }
  {
    product-name: (string-utf8 128),
    product-description: (string-utf8 1024),
    manufacturer: principal,
    lot-number: (string-ascii 64),
    created-at: uint,
    product-status: (string-ascii 32),  ;; "created", "in-transit", "delivered", "sold", "recalled"
    product-category: (string-ascii 64),
    origin-location: (string-utf8 128),
    current-custodian: principal,
    delivery-destination: (optional (string-utf8 128)),
    expected-arrival: (optional uint),
    metadata-uri: (optional (string-utf8 256))
  }
)

;; Supply chain checkpoints
(define-map checkpoint-records
  { product-id: uint, checkpoint-id: uint }
  {
    checkpoint-location: (string-utf8 128),
    recorded-at: uint,
    custodian: principal,
    verifier: principal,
    checkpoint-type: (string-ascii 32),  ;; "manufacture", "shipping", "customs", "warehouse", "retail", "delivery"
    temperature-reading: (optional int),         ;; For temperature-sensitive goods
    humidity-level: (optional uint),           ;; For humidity-sensitive goods
    observations: (optional (string-utf8 512)),
    attestation-hash: (buff 32)         ;; Hash of checkpoint attestation document
  }
)

;; Authorized verifiers for each company
(define-map authorized-verifiers
  { organization: principal, verifier: principal }
  {
    verifier-name: (string-utf8 128),
    verifier-role: (string-ascii 64),
    authorized-at: uint,
    authorized-by: principal,
    verifier-active: bool
  }
)

;; Custody transfers
(define-map custody-transfers
  { product-id: uint, transfer-id: uint }
  {
    initiator: principal,
    recipient: principal,
    initiated-at: uint,
    completed-at: (optional uint),
    transfer-status: (string-ascii 32),  ;; "pending", "completed", "rejected", "cancelled"
    conditions: (optional (string-utf8 512))
  }
)

;; Certifications and compliance
(define-map certification-records
  { product-id: uint, certification-type: (string-ascii 64) }
  {
    issuer: principal,
    issued-at: uint,
    expires-at: uint,
    certification-hash: (buff 32),
    certification-uri: (optional (string-utf8 256)),
    certification-status: (string-ascii 32)  ;; "valid", "expired", "revoked"
  }
)

;; Next available IDs
(define-data-var next-product-id uint u0)
(define-map next-checkpoint-id { product-id: uint } { id: uint })
(define-map next-transfer-id { product-id: uint } { id: uint })

;; ... existing code ...

;; Helper function to convert string to buffer for hashing
(define-private (utf8-string-to-buffer (val (string-utf8 512)))
  ;; In a real implementation, you would convert the string to bytes
  0x68656c6c6f20776f726c64 ;; Example buffer (represents "hello world" in hex)
)

;; Helper function to convert ascii string to buffer for hashing
(define-private (ascii-string-to-buffer (val (string-ascii 64)))
  ;; In a real implementation, you would convert the string to bytes
  0x68656c6c6f20776f726c64 ;; Example buffer (represents "hello world" in hex)
)

;; Helper function to convert principal to string
(define-private (principal-to-utf8 (val principal))
  u"principal" ;; Simplified implementation
)

;; Register a new product
(define-public (register-product
                (product-name (string-utf8 128))
                (product-description (string-utf8 1024))
                (lot-number (string-ascii 64))
                (product-category (string-ascii 64))
                (origin-location (string-utf8 128))
                (metadata-uri (optional (string-utf8 256))))
  (let
    ((product-id (var-get next-product-id)))
    
    ;; Create the product record
    (map-set product-registry
      { product-id: product-id }
      {
        product-name: product-name,
        product-description: product-description,
        manufacturer: tx-sender,
        lot-number: lot-number,
        created-at: block-height,
        product-status: "created",
        product-category: product-category,
        origin-location: origin-location,
        current-custodian: tx-sender,
        delivery-destination: none,
        expected-arrival: none,
        metadata-uri: metadata-uri
      }
    )
    
    ;; Initialize checkpoint counter
    (map-set next-checkpoint-id
      { product-id: product-id }
      { id: u0 }
    )
    
    ;; Initialize transfer counter
    (map-set next-transfer-id
      { product-id: product-id }
      { id: u0 }
    )
    
    ;; Create initial manufacturing checkpoint
    (try! (record-checkpoint
            product-id
            origin-location
            "manufacture"
            none
            none
            (some u"Product manufactured with batch code")
            (sha256 (ascii-string-to-buffer lot-number))
          ))
    
    ;; Increment product ID counter
    (var-set next-product-id (+ product-id u1))
    
    (ok product-id)
  )
)

;; Add a checkpoint to a product's supply chain journey
(define-public (record-checkpoint
                (product-id uint)
                (checkpoint-location (string-utf8 128))
                (checkpoint-type (string-ascii 32))
                (temperature-reading (optional int))
                (humidity-level (optional uint))
                (observations (optional (string-utf8 512)))
                (attestation-hash (buff 32)))
  (let
    ((product (unwrap! (map-get? product-registry { product-id: product-id }) (err u"Product not found")))
     (checkpoint-counter (unwrap! (map-get? next-checkpoint-id { product-id: product-id }) 
                                 (err u"Counter not found")))
     (checkpoint-id (get id checkpoint-counter)))
    
    ;; Validate
    (asserts! (or (is-eq tx-sender (get current-custodian product)) 
                  (is-verifier-authorized (get current-custodian product) tx-sender))
              (err u"Not authorized to add checkpoint"))
    (asserts! (not (is-eq (get product-status product) "recalled")) (err u"Product has been recalled"))
    
    ;; Create the checkpoint
    (map-set checkpoint-records
      { product-id: product-id, checkpoint-id: checkpoint-id }
      {
        checkpoint-location: checkpoint-location,
        recorded-at: block-height,
        custodian: (get current-custodian product),
        verifier: tx-sender,
        checkpoint-type: checkpoint-type,
        temperature-reading: temperature-reading,
        humidity-level: humidity-level,
        observations: observations,
        attestation-hash: attestation-hash
      }
    )
    
    ;; Update product status based on checkpoint type
    (map-set product-registry
      { product-id: product-id }
      (merge product 
        { 
          product-status: (if (is-eq checkpoint-type "delivery") "delivered" 
                    (if (is-eq checkpoint-type "retail-sale") "sold" "in-transit"))
        }
      )
    )
    
    ;; Increment checkpoint counter
    (map-set next-checkpoint-id
      { product-id: product-id }
      { id: (+ checkpoint-id u1) }
    )
    
    (ok checkpoint-id)
  )
)

;; Check if a principal is an authorized verifier for a company
(define-private (is-verifier-authorized (organization principal) (verifier principal))
  (match (map-get? authorized-verifiers { organization: organization, verifier: verifier })
    verifier-data (get verifier-active verifier-data)
    false
  )
)

;; Authorize a verifier for a company
(define-public (authorize-verifier
                (verifier principal)
                (verifier-name (string-utf8 128))
                (verifier-role (string-ascii 64)))
  (begin
    ;; Set verifier as authorized
    (map-set authorized-verifiers
      { organization: tx-sender, verifier: verifier }
      {
        verifier-name: verifier-name,
        verifier-role: verifier-role,
        authorized-at: block-height,
        authorized-by: tx-sender,
        verifier-active: true
      }
    )
    
    (ok true)
  )
)

;; Revoke a verifier's authorization
(define-public (deauthorize-verifier (verifier principal))
  (let
    ((verifier-data (unwrap! (map-get? authorized-verifiers { organization: tx-sender, verifier: verifier })
                            (err u"Verifier not found"))))
    
    (map-set authorized-verifiers
      { organization: tx-sender, verifier: verifier }
      (merge verifier-data { verifier-active: false })
    )
    
    (ok true)
  )
)

;; Initiate custody transfer of a product
(define-public (initiate-transfer
                (product-id uint)
                (recipient principal)
                (conditions (optional (string-utf8 512))))
  (let
    ((product (unwrap! (map-get? product-registry { product-id: product-id }) (err u"Product not found")))
     (transfer-counter (unwrap! (map-get? next-transfer-id { product-id: product-id }) 
                               (err u"Counter not found")))
     (transfer-id (get id transfer-counter)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get current-custodian product)) 
              (err u"Only current custodian can initiate transfer"))
    (asserts! (not (is-eq (get product-status product) "recalled")) 
              (err u"Product has been recalled"))
    
    ;; Create transfer record
    (map-set custody-transfers
      { product-id: product-id, transfer-id: transfer-id }
      {
        initiator: tx-sender,
        recipient: recipient,
        initiated-at: block-height,
        completed-at: none,
        transfer-status: "pending",
        conditions: conditions
      }
    )
    
    ;; Increment transfer counter
    (map-set next-transfer-id
      { product-id: product-id }
      { id: (+ transfer-id u1) }
    )
    
    (ok transfer-id)
  )
)

;; Accept a custody transfer
(define-public (accept-transfer (product-id uint) (transfer-id uint))
  (let
    ((product (unwrap! (map-get? product-registry { product-id: product-id }) (err u"Product not found")))
     (transfer (unwrap! (map-get? custody-transfers { product-id: product-id, transfer-id: transfer-id })
                       (err u"Transfer not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get recipient transfer)) (err u"Only recipient can accept"))
    (asserts! (is-eq (get transfer-status transfer) "pending") (err u"Transfer not pending"))
    
    ;; Update transfer record
    (map-set custody-transfers
      { product-id: product-id, transfer-id: transfer-id }
      (merge transfer 
        { 
          completed-at: (some block-height),
          transfer-status: "completed"
        }
      )
    )
    
    ;; Update product custodian
    (map-set product-registry
      { product-id: product-id }
      (merge product { current-custodian: tx-sender })
    )
    
    ;; Add a checkpoint for the custody transfer
    (try! (record-checkpoint
            product-id
            u"custody-transfer" ;; Generic location for transfer as utf8
            "transfer"
            none
            none
            (some u"Custody transferred")
            (sha256 (utf8-string-to-buffer u"custody-transfer"))
          ))
    
    (ok true)
  )
)

;; Reject a custody transfer
(define-public (reject-transfer (product-id uint) (transfer-id uint) (rejection-reason (string-utf8 512)))
  (let
    ((transfer (unwrap! (map-get? custody-transfers { product-id: product-id, transfer-id: transfer-id })
                       (err u"Transfer not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get recipient transfer)) (err u"Only recipient can reject"))
    (asserts! (is-eq (get transfer-status transfer) "pending") (err u"Transfer not pending"))
    
    ;; Update transfer record
    (map-set custody-transfers
      { product-id: product-id, transfer-id: transfer-id }
      (merge transfer 
        { 
          completed-at: (some block-height),
          transfer-status: "rejected",
          conditions: (some rejection-reason)
        }
      )
    )
    
    (ok true)
  )
)

;; Cancel a pending transfer (only current custodian)
(define-public (cancel-transfer (product-id uint) (transfer-id uint))
  (let
    ((transfer (unwrap! (map-get? custody-transfers { product-id: product-id, transfer-id: transfer-id })
                       (err u"Transfer not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get initiator transfer)) (err u"Only sender can cancel"))
    (asserts! (is-eq (get transfer-status transfer) "pending") (err u"Transfer not pending"))
    
    ;; Update transfer record
    (map-set custody-transfers
      { product-id: product-id, transfer-id: transfer-id }
      (merge transfer 
        { 
          completed-at: (some block-height),
          transfer-status: "cancelled"
        }
      )
    )
    
    (ok true)
  )
)

;; Add certification to a product
(define-public (add-certification
                (product-id uint)
                (certification-type (string-ascii 64))
                (expires-at uint)
                (certification-hash (buff 32))
                (certification-uri (optional (string-utf8 256))))
  (let
    ((product (unwrap! (map-get? product-registry { product-id: product-id }) (err u"Product not found"))))
    
    ;; Validate
    (asserts! (or (is-eq tx-sender (get manufacturer product)) 
                  (is-verifier-authorized (get manufacturer product) tx-sender))
              (err u"Not authorized to add certification"))
    (asserts! (> expires-at block-height) (err u"Certification must be valid for future blocks"))
    
    ;; Add certification
    (map-set certification-records
      { product-id: product-id, certification-type: certification-type }
      {
        issuer: tx-sender,
        issued-at: block-height,
        expires-at: expires-at,
        certification-hash: certification-hash,
        certification-uri: certification-uri,
        certification-status: "valid"
      }
    )
    
    (ok true)
  )
)

;; Revoke a certification
(define-public (revoke-certification (product-id uint) (certification-type (string-ascii 64)))
  (let
    ((certification (unwrap! (map-get? certification-records 
                               { product-id: product-id, certification-type: certification-type })
                             (err u"Certification not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get issuer certification)) 
              (err u"Only issuer can revoke certification"))
    
    ;; Update certification
    (map-set certification-records
      { product-id: product-id, certification-type: certification-type }
      (merge certification { certification-status: "revoked" })
    )
    
    (ok true)
  )
)

;; Issue a product recall
(define-public (recall-product (product-id uint) (recall-reason (string-utf8 512)))
  (let
    ((product (unwrap! (map-get? product-registry { product-id: product-id }) (err u"Product not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get manufacturer product)) 
              (err u"Only manufacturer can recall product"))
    
    ;; Update product status
    (map-set product-registry
      { product-id: product-id }
      (merge product { product-status: "recalled" })
    )
    
    ;; Add a checkpoint for the recall
    (try! (record-checkpoint
            product-id
            u"recall" ;; Using utf8 string for location
            "recall"
            none
            none
            (some recall-reason)
            (sha256 (utf8-string-to-buffer recall-reason))
          ))
    
    (ok true)
  )
)

;; Set final destination and expected delivery
(define-public (set-shipping-details
                (product-id uint)
                (delivery-destination (string-utf8 128))
                (expected-arrival uint))
  (let
    ((product (unwrap! (map-get? product-registry { product-id: product-id }) (err u"Product not found"))))
    
    ;; Validate
    (asserts! (or (is-eq tx-sender (get current-custodian product)) 
                  (is-verifier-authorized (get current-custodian product) tx-sender))
              (err u"Not authorized to set shipping details"))
    
    ;; Update product
    (map-set product-registry
      { product-id: product-id }
      (merge product 
        { 
          delivery-destination: (some delivery-destination),
          expected-arrival: (some expected-arrival)
        }
      )
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get product details
(define-read-only (get-product-details (product-id uint))
  (ok (unwrap! (map-get? product-registry { product-id: product-id }) (err u"Product not found")))
)

;; Get checkpoint details
(define-read-only (get-checkpoint (product-id uint) (checkpoint-id uint))
  (ok (unwrap! (map-get? checkpoint-records { product-id: product-id, checkpoint-id: checkpoint-id })
              (err u"Checkpoint not found")))
)

;; Get transfer details
(define-read-only (get-transfer (product-id uint) (transfer-id uint))
  (ok (unwrap! (map-get? custody-transfers { product-id: product-id, transfer-id: transfer-id })
              (err u"Transfer not found")))
)

;; Get certification details
(define-read-only (get-certification (product-id uint) (certification-type (string-ascii 64)))
  (ok (unwrap! (map-get? certification-records { product-id: product-id, certification-type: certification-type })
              (err u"Certification not found")))
)

;; Check if certification is valid
(define-read-only (is-certification-valid (product-id uint) (certification-type (string-ascii 64)))
  (match (map-get? certification-records { product-id: product-id, certification-type: certification-type })
    certification (and (is-eq (get certification-status certification) "valid")
                       (> (get expires-at certification) block-height))
    false
  )
)

;; Verify product authenticity (basic check)
(define-read-only (verify-product-authenticity (product-id uint))
  (match (map-get? product-registry { product-id: product-id })
    product (ok {
              authentic: true,
              manufacturer: (get manufacturer product),
              batch-code: (get lot-number product),
              status: (get product-status product)
            })
    (err u"Product not found")
  )
)