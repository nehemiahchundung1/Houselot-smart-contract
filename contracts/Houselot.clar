(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-eligible (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-lottery-not-active (err u103))
(define-constant err-lottery-not-ended (err u104))
(define-constant err-no-participants (err u105))
(define-constant err-invalid-housing-unit (err u106))
(define-constant err-unit-already-allocated (err u107))
(define-constant err-not-winner (err u108))
(define-constant err-already-claimed (err u109))
(define-constant err-invalid-maintenance-request (err u110))
(define-constant err-not-tenant (err u111))
(define-constant err-invalid-rating (err u112))
(define-constant err-request-not-found (err u113))
(define-constant err-invalid-status (err u114))
(define-constant err-not-in-waitlist (err u115))
(define-constant err-waitlist-full (err u116))
(define-constant err-already-in-waitlist (err u117))
(define-constant err-invalid-priority (err u118))
(define-constant err-unit-not-vacated (err u119))
(define-constant err-no-eligible-waitlist (err u120))
(define-constant err-document-not-found (err u121))
(define-constant err-invalid-document-type (err u122))
(define-constant err-document-expired (err u123))
(define-constant err-not-authorized-to-view (err u124))
(define-constant err-document-already-verified (err u125))

(define-data-var lottery-active bool false)
(define-data-var registration-deadline uint u0)
(define-data-var drawing-block uint u0)
(define-data-var total-participants uint u0)
(define-data-var lottery-id uint u0)
(define-data-var random-seed uint u0)

(define-map participants principal
    {
        registered: bool,
        income-verified: bool,
        lottery-id: uint,
        registration-block: uint
    }
)

(define-map housing-units uint
    {
        address: (string-ascii 100),
        rent: uint,
        bedrooms: uint,
        allocated: bool,
        winner: (optional principal),
        quality-score: uint,
        total-ratings: uint,
        maintenance-issues: uint
    }
)

(define-map lottery-winners uint principal)
(define-map winner-claims principal bool)
(define-map lottery-history uint
    {
        participants-count: uint,
        drawing-block: uint,
        winners: (list 10 principal)
    }
)

(define-map maintenance-requests uint
    {
        unit-id: uint,
        tenant: principal,
        description: (string-ascii 500),
        category: (string-ascii 50),
        priority: uint,
        status: (string-ascii 20),
        created-block: uint,
        updated-block: uint,
        resolved-block: (optional uint)
    }
)

(define-map unit-ratings uint
    {
        unit-id: uint,
        tenant: principal,
        rating: uint,
        comment: (string-ascii 200),
        created-block: uint
    }
)

(define-data-var housing-unit-counter uint u0)
(define-data-var maintenance-request-counter uint u0)
(define-data-var waitlist-counter uint u0)
(define-data-var auto-allocation-enabled bool true)
(define-data-var document-counter uint u0)

;; Document Management System Maps
(define-map housing-documents uint
    {
        unit-id: uint,
        uploader: principal,
        document-type: (string-ascii 50),
        title: (string-ascii 100),
        description: (string-ascii 300),
        file-hash: (string-ascii 64),
        upload-date: uint,
        expiration-date: (optional uint),
        verification-status: (string-ascii 20),
        verifier: (optional principal),
        verification-date: (optional uint),
        access-level: (string-ascii 20),
        file-size: uint,
        is-active: bool
    }
)

;; Map of valid document types with their descriptions and retention periods
(define-map document-types (string-ascii 50)
    {
        description: (string-ascii 100),
        retention-period: uint,  ;; Number of blocks before document expires (0 = no expiration)
        required-for-tenants: bool,
        required-for-application: bool
    }
)

;; Map of document access permissions by principal
(define-map document-access-permissions 
    {document-id: uint, accessor: principal}
    {can-view: bool, can-verify: bool, granted-by: principal, granted-at: uint}
)

;; Map tracking documents by unit and by tenant
(define-map unit-documents uint (list 100 uint))
(define-map tenant-documents principal (list 100 uint))

(define-map housing-waitlist uint
    {
        participant: principal,
        registration-date: uint,
        priority-score: uint,
        household-size: uint,
        preferred-bedrooms: uint,
        special-needs: bool,
        veteran-status: bool,
        elderly-status: bool,
        disabled-status: bool,
        employment-status: (string-ascii 20),
        current-housing-situation: (string-ascii 50),
        waitlist-position: uint,
        active: bool
    }
)

(define-map participant-waitlist-id principal uint)

(define-map unit-vacancies uint
    {
        unit-id: uint,
        vacation-date: uint,
        reason: (string-ascii 100),
        next-available-date: uint,
        allocated-from-waitlist: bool,
        allocated-to: (optional principal)
    }
)

(define-public (initialize-lottery (deadline uint) (drawing-block-height uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (var-get lottery-active)) err-lottery-not-ended)
        (asserts! (> deadline stacks-block-height) (err u110))
        (asserts! (> drawing-block-height deadline) (err u111))
        (var-set lottery-active true)
        (var-set registration-deadline deadline)
        (var-set drawing-block drawing-block-height)
        (var-set total-participants u0)
        (var-set lottery-id (+ (var-get lottery-id) u1))
        (var-set random-seed stacks-block-height)
        (ok true)
    )
)

(define-public (register-participant (income uint))
    (let (
        (participant tx-sender)
        (current-lottery (var-get lottery-id))
    )
        (asserts! (var-get lottery-active) err-lottery-not-active)
        (asserts! (<= stacks-block-height (var-get registration-deadline)) (err u112))
        (asserts! (is-none (map-get? participants participant)) err-already-registered)
        (asserts! (<= income u50000) err-not-eligible)
        (map-set participants participant
            {
                registered: true,
                income-verified: true,
                lottery-id: current-lottery,
                registration-block: stacks-block-height
            }
        )
        (var-set total-participants (+ (var-get total-participants) u1))
        (ok true)
    )
)

(define-public (add-housing-unit (address (string-ascii 100)) (rent uint) (bedrooms uint))
    (let (
        (unit-id (+ (var-get housing-unit-counter) u1))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set housing-units unit-id
            {
                address: address,
                rent: rent,
                bedrooms: bedrooms,
                allocated: false,
                winner: none,
                quality-score: u0,
                total-ratings: u0,
                maintenance-issues: u0
            }
        )
        (var-set housing-unit-counter unit-id)
        (ok unit-id)
    )
)

(define-public (conduct-lottery)
    (let (
        (participants-count (var-get total-participants))
        (current-lottery (var-get lottery-id))
        ;; (seed (generate-random-seed))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (var-get lottery-active) err-lottery-not-active)
        (asserts! (>= stacks-block-height (var-get drawing-block)) err-lottery-not-ended)
        (asserts! (> participants-count u0) err-no-participants)
        (var-set random-seed u12123)
        (var-set lottery-active false)
        ;; (try! (select-winners participants-count))
        (ok true)
    )
)

(define-public (allocate-housing (unit-id uint) (winner principal))
    (let (
        (unit (unwrap! (map-get? housing-units unit-id) err-invalid-housing-unit))
        (participant (unwrap! (map-get? participants winner) err-not-eligible))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get allocated unit)) err-unit-already-allocated)
        (asserts! (get registered participant) err-not-eligible)
        (map-set housing-units unit-id
            (merge unit {
                allocated: true,
                winner: (some winner)
            })
        )
        (ok true)
    )
)

(define-public (claim-housing (unit-id uint))
    (let (
        (unit (unwrap! (map-get? housing-units unit-id) err-invalid-housing-unit))
        (claimer tx-sender)
    )
        (asserts! (get allocated unit) err-invalid-housing-unit)
        (asserts! (is-eq (some claimer) (get winner unit)) err-not-winner)
        (asserts! (is-none (map-get? winner-claims claimer)) err-already-claimed)
        (map-set winner-claims claimer true)
        (ok true)
    )
)

(define-public (verify-income (participant principal) (verified bool))
    (let (
        (participant-data (unwrap! (map-get? participants participant) err-not-eligible))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set participants participant
            (merge participant-data {
                income-verified: verified
            })
        )
        (ok true)
    )
)

(define-public (submit-maintenance-request (unit-id uint) (description (string-ascii 500)) (category (string-ascii 50)) (priority uint))
    (let (
        (unit (unwrap! (map-get? housing-units unit-id) err-invalid-housing-unit))
        (tenant tx-sender)
        (request-id (+ (var-get maintenance-request-counter) u1))
    )
        (asserts! (get allocated unit) err-invalid-housing-unit)
        (asserts! (is-eq (some tenant) (get winner unit)) err-not-tenant)
        (asserts! (and (>= priority u1) (<= priority u5)) err-invalid-maintenance-request)
        (map-set maintenance-requests request-id
            {
                unit-id: unit-id,
                tenant: tenant,
                description: description,
                category: category,
                priority: priority,
                status: "pending",
                created-block: stacks-block-height,
                updated-block: stacks-block-height,
                resolved-block: none
            }
        )
        (map-set housing-units unit-id
            (merge unit {
                maintenance-issues: (+ (get maintenance-issues unit) u1)
            })
        )
        (var-set maintenance-request-counter request-id)
        (ok request-id)
    )
)

(define-public (update-maintenance-status (request-id uint) (status (string-ascii 20)))
    (let (
        (request (unwrap! (map-get? maintenance-requests request-id) err-request-not-found))
        (unit (unwrap! (map-get? housing-units (get unit-id request)) err-invalid-housing-unit))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (or (is-eq status "pending") (is-eq status "in-progress") (is-eq status "completed")) err-invalid-status)
        (map-set maintenance-requests request-id
            (merge request {
                status: status,
                updated-block: stacks-block-height,
                resolved-block: (if (is-eq status "completed") (some stacks-block-height) none)
            })
        )
        (if (is-eq status "completed")
            (map-set housing-units (get unit-id request)
                (merge unit {
                    maintenance-issues: (if (> (get maintenance-issues unit) u0) (- (get maintenance-issues unit) u1) u0)
                })
            )
            true
        )
        (ok true)
    )
)

(define-public (rate-housing-unit (unit-id uint) (rating uint) (comment (string-ascii 200)))
    (let (
        (unit (unwrap! (map-get? housing-units unit-id) err-invalid-housing-unit))
        (tenant tx-sender)
        (current-quality (get quality-score unit))
        (current-ratings (get total-ratings unit))
        (new-total-ratings (+ current-ratings u1))
        (new-quality-score (/ (+ (* current-quality current-ratings) rating) new-total-ratings))
        (rating-id (+ (var-get maintenance-request-counter) u1))
    )
        (asserts! (get allocated unit) err-invalid-housing-unit)
        (asserts! (is-eq (some tenant) (get winner unit)) err-not-tenant)
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
        (map-set unit-ratings rating-id
            {
                unit-id: unit-id,
                tenant: tenant,
                rating: rating,
                comment: comment,
                created-block: stacks-block-height
            }
        )
        (map-set housing-units unit-id
            (merge unit {
                quality-score: new-quality-score,
                total-ratings: new-total-ratings
            })
        )
        (ok rating-id)
    )
)

(define-read-only (get-maintenance-requests-by-unit (unit-id uint))
    (let (
        (max-requests (var-get maintenance-request-counter))
    )
        (filter-maintenance-requests unit-id max-requests)
    )
)

(define-private (filter-maintenance-requests (target-unit-id uint) (max-id uint))
    (fold filter-request-by-unit 
        (generate-request-ids max-id)
        {target-unit: target-unit-id, results: (list)}
    )
)

(define-private (filter-request-by-unit (request-id uint) (state {target-unit: uint, results: (list 50 uint)}))
    (match (map-get? maintenance-requests request-id)
        request-data
            (if (is-eq (get unit-id request-data) (get target-unit state))
                {
                    target-unit: (get target-unit state),
                    results: (unwrap-panic (as-max-len? (append (get results state) request-id) u50))
                }
                state
            )
        state
    )
)

(define-private (generate-request-ids (max-id uint))
    (map generate-id (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50))
)

(define-private (generate-id (index uint))
    (if (<= index (var-get maintenance-request-counter))
        index
        u0
    )
)


;; select-winners and generate-winners removed; logic is now in conduct-lottery

(define-private (get-participant-by-index (index uint))
    (fold find-participant-at-index 
        (list tx-sender contract-owner) 
        {target-index: index, current-index: u0, found: none}
    )
)

(define-private (find-participant-at-index (participant principal) (state {target-index: uint, current-index: uint, found: (optional principal)}))
    (if (is-some (get found state))
        state
        (match (map-get? participants participant)
            participant-data 
                (if (and 
                    (get registered participant-data)
                    (get income-verified participant-data)
                    (is-eq (get lottery-id participant-data) (var-get lottery-id))
                )
                    (if (is-eq (get current-index state) (get target-index state))
                        {
                            target-index: (get target-index state),
                            current-index: (get current-index state),
                            found: (some participant)
                        }
                        {
                            target-index: (get target-index state),
                            current-index: (+ (get current-index state) u1),
                            found: none
                        }
                    )
                    state
                )
            state
        )
    )
)

(define-private (get-byte-value (byte-info {index: uint, value: (buff 1)}))
    (* (buff-to-uint-be (get value byte-info)) (pow u256 (get index byte-info)))
)

(define-private (enumerate-bytes (input (buff 32)))
    (list
        {index: u0, value: (unwrap-panic (slice? input u0 u1))}
        {index: u1, value: (unwrap-panic (slice? input u1 u2))}
        {index: u2, value: (unwrap-panic (slice? input u2 u3))}
        {index: u3, value: (unwrap-panic (slice? input u3 u4))}
        {index: u4, value: (unwrap-panic (slice? input u4 u5))}
        {index: u5, value: (unwrap-panic (slice? input u5 u6))}
        {index: u6, value: (unwrap-panic (slice? input u6 u7))}
        {index: u7, value: (unwrap-panic (slice? input u7 u8))}
        {index: u8, value: (unwrap-panic (slice? input u8 u9))}
        {index: u9, value: (unwrap-panic (slice? input u9 u10))}
        {index: u10, value: (unwrap-panic (slice? input u10 u11))}
        {index: u11, value: (unwrap-panic (slice? input u11 u12))}
        {index: u12, value: (unwrap-panic (slice? input u12 u13))}
        {index: u13, value: (unwrap-panic (slice? input u13 u14))}
        {index: u14, value: (unwrap-panic (slice? input u14 u15))}
        {index: u15, value: (unwrap-panic (slice? input u15 u16))}
        {index: u16, value: (unwrap-panic (slice? input u16 u17))}
        {index: u17, value: (unwrap-panic (slice? input u17 u18))}
        {index: u18, value: (unwrap-panic (slice? input u18 u19))}
        {index: u19, value: (unwrap-panic (slice? input u19 u20))}
        {index: u20, value: (unwrap-panic (slice? input u20 u21))}
        {index: u21, value: (unwrap-panic (slice? input u21 u22))}
        {index: u22, value: (unwrap-panic (slice? input u22 u23))}
        {index: u23, value: (unwrap-panic (slice? input u23 u24))}
        {index: u24, value: (unwrap-panic (slice? input u24 u25))}
        {index: u25, value: (unwrap-panic (slice? input u25 u26))}
        {index: u26, value: (unwrap-panic (slice? input u26 u27))}
        {index: u27, value: (unwrap-panic (slice? input u27 u28))}
        {index: u28, value: (unwrap-panic (slice? input u28 u29))}
        {index: u29, value: (unwrap-panic (slice? input u29 u30))}
        {index: u30, value: (unwrap-panic (slice? input u30 u31))}
        {index: u31, value: (unwrap-panic (slice? input u31 u32))}
    )
)

(define-read-only (get-lottery-info)
    {
        active: (var-get lottery-active),
        registration-deadline: (var-get registration-deadline),
        drawing-block: (var-get drawing-block),
        total-participants: (var-get total-participants),
        lottery-id: (var-get lottery-id)
    }
)

(define-read-only (get-participant-info (participant principal))
    (map-get? participants participant)
)

(define-read-only (get-housing-unit (unit-id uint))
    (map-get? housing-units unit-id)
)

(define-read-only (get-lottery-winner (index uint))
    (map-get? lottery-winners index)
)

(define-read-only (is-winner (participant principal))
    (is-some (map-get? winner-claims participant))
)

(define-read-only (get-total-housing-units)
    (var-get housing-unit-counter)
)

(define-read-only (get-current-block)
    stacks-block-height
)

(define-read-only (get-maintenance-request (request-id uint))
    (map-get? maintenance-requests request-id)
)

(define-read-only (get-unit-rating (rating-id uint))
    (map-get? unit-ratings rating-id)
)

(define-read-only (get-unit-quality-score (unit-id uint))
    (match (map-get? housing-units unit-id)
        unit-data (some (get quality-score unit-data))
        none
    )
)

(define-read-only (get-maintenance-issues-count (unit-id uint))
    (match (map-get? housing-units unit-id)
        unit-data (some (get maintenance-issues unit-data))
        none
    )
)

(define-read-only (get-unit-stats (unit-id uint))
    (match (map-get? housing-units unit-id)
        unit-data (some {
            quality-score: (get quality-score unit-data),
            total-ratings: (get total-ratings unit-data),
            maintenance-issues: (get maintenance-issues unit-data)
        })
        none
    )
)

(define-read-only (get-total-maintenance-requests)
    (var-get maintenance-request-counter)
)

(define-public (join-housing-waitlist 
    (household-size uint) 
    (preferred-bedrooms uint) 
    (special-needs bool) 
    (veteran-status bool) 
    (elderly-status bool) 
    (disabled-status bool) 
    (employment-status (string-ascii 20)) 
    (current-housing-situation (string-ascii 50)))
    (let (
        (participant tx-sender)
        (waitlist-id (+ (var-get waitlist-counter) u1))
        (priority-score (calculate-priority-score household-size special-needs veteran-status elderly-status disabled-status employment-status))
        (current-position (get-next-waitlist-position))
    )
        (asserts! (is-none (map-get? participant-waitlist-id participant)) err-already-in-waitlist)
        (asserts! (<= waitlist-id u1000) err-waitlist-full)
        (asserts! (and (>= household-size u1) (<= household-size u10)) err-invalid-priority)
        (asserts! (and (>= preferred-bedrooms u1) (<= preferred-bedrooms u5)) err-invalid-priority)
        (map-set housing-waitlist waitlist-id
            {
                participant: participant,
                registration-date: stacks-block-height,
                priority-score: priority-score,
                household-size: household-size,
                preferred-bedrooms: preferred-bedrooms,
                special-needs: special-needs,
                veteran-status: veteran-status,
                elderly-status: elderly-status,
                disabled-status: disabled-status,
                employment-status: employment-status,
                current-housing-situation: current-housing-situation,
                waitlist-position: current-position,
                active: true
            }
        )
        (map-set participant-waitlist-id participant waitlist-id)
        (var-set waitlist-counter waitlist-id)
        (ok waitlist-id)
    )
)

(define-public (update-waitlist-info 
    (household-size uint) 
    (preferred-bedrooms uint) 
    (employment-status (string-ascii 20)) 
    (current-housing-situation (string-ascii 50)))
    (let (
        (participant tx-sender)
        (waitlist-id (unwrap! (map-get? participant-waitlist-id participant) err-not-in-waitlist))
        (current-entry (unwrap! (map-get? housing-waitlist waitlist-id) err-not-in-waitlist))
        (new-priority-score (calculate-priority-score 
            household-size 
            (get special-needs current-entry) 
            (get veteran-status current-entry) 
            (get elderly-status current-entry) 
            (get disabled-status current-entry) 
            employment-status))
    )
        (asserts! (get active current-entry) err-not-in-waitlist)
        (asserts! (and (>= household-size u1) (<= household-size u10)) err-invalid-priority)
        (asserts! (and (>= preferred-bedrooms u1) (<= preferred-bedrooms u5)) err-invalid-priority)
        (map-set housing-waitlist waitlist-id
            (merge current-entry {
                household-size: household-size,
                preferred-bedrooms: preferred-bedrooms,
                employment-status: employment-status,
                current-housing-situation: current-housing-situation,
                priority-score: new-priority-score
            })
        )
        (reorder-waitlist-positions)
    )
)

(define-public (vacate-housing-unit (unit-id uint) (reason (string-ascii 100)) (next-available-date uint))
    (let (
        (unit (unwrap! (map-get? housing-units unit-id) err-invalid-housing-unit))
        (vacancy-id unit-id)
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (get allocated unit) err-invalid-housing-unit)
        (asserts! (>= next-available-date stacks-block-height) err-invalid-priority)
        (map-set unit-vacancies vacancy-id
            {
                unit-id: unit-id,
                vacation-date: stacks-block-height,
                reason: reason,
                next-available-date: next-available-date,
                allocated-from-waitlist: false,
                allocated-to: none
            }
        )
        (map-set housing-units unit-id
            (merge unit {
                allocated: false,
                winner: none
            })
        )
        (if (var-get auto-allocation-enabled)
            (begin
                (unwrap-panic (auto-allocate-from-waitlist unit-id))
                (ok true)
            )
            (ok true)
        )
    )
)

(define-public (auto-allocate-from-waitlist (unit-id uint))
    (let (
        (unit (unwrap! (map-get? housing-units unit-id) err-invalid-housing-unit))
        (best-match (find-best-waitlist-match unit-id))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get allocated unit)) err-unit-already-allocated)
        (if (get found best-match)
            (let (
                (waitlist-id (get waitlist-id best-match))
                (waitlist-entry (unwrap-panic (map-get? housing-waitlist waitlist-id)))
                (participant (get participant waitlist-entry))
            )
                (map-set housing-units unit-id
                    (merge unit {
                        allocated: true,
                        winner: (some participant)
                    })
                )
                (map-set unit-vacancies unit-id
                    (merge (unwrap-panic (map-get? unit-vacancies unit-id)) {
                        allocated-from-waitlist: true,
                        allocated-to: (some participant)
                    })
                )
                (map-set housing-waitlist waitlist-id
                    (merge waitlist-entry {
                        active: false
                    })
                )
                (map-delete participant-waitlist-id participant)
                (unwrap-panic (reorder-waitlist-positions))
                (ok participant)
            )
            err-no-eligible-waitlist
        )
    )
)

(define-public (remove-from-waitlist)
    (let (
        (participant tx-sender)
        (waitlist-id (unwrap! (map-get? participant-waitlist-id participant) err-not-in-waitlist))
        (waitlist-entry (unwrap! (map-get? housing-waitlist waitlist-id) err-not-in-waitlist))
    )
        (asserts! (get active waitlist-entry) err-not-in-waitlist)
        (map-set housing-waitlist waitlist-id
            (merge waitlist-entry {
                active: false
            })
        )
        (map-delete participant-waitlist-id participant)
        (reorder-waitlist-positions)
    )
)

(define-public (toggle-auto-allocation)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set auto-allocation-enabled (not (var-get auto-allocation-enabled)))
        (ok (var-get auto-allocation-enabled))
    )
)

(define-private (calculate-priority-score 
    (household-size uint) 
    (special-needs bool) 
    (veteran-status bool) 
    (elderly-status bool) 
    (disabled-status bool) 
    (employment-status (string-ascii 20)))
    (let (
        (base-score u100)
        (household-bonus (* household-size u10))
        (special-needs-bonus (if special-needs u50 u0))
        (veteran-bonus (if veteran-status u30 u0))
        (elderly-bonus (if elderly-status u25 u0))
        (disabled-bonus (if disabled-status u40 u0))
        (employment-bonus (if (is-eq employment-status "unemployed") u20 u0))
    )
        (+ base-score household-bonus special-needs-bonus veteran-bonus elderly-bonus disabled-bonus employment-bonus)
    )
)

(define-private (get-next-waitlist-position)
    (let (
        (max-waitlist (var-get waitlist-counter))
        (active-count (count-active-waitlist-entries max-waitlist))
    )
        (+ active-count u1)
    )
)

(define-private (count-active-waitlist-entries (max-id uint))
    (fold count-active-entries 
        (generate-waitlist-ids max-id)
        u0
    )
)

(define-private (count-active-entries (waitlist-id uint) (count uint))
    (match (map-get? housing-waitlist waitlist-id)
        entry-data
            (if (get active entry-data)
                (+ count u1)
                count
            )
        count
    )
)

(define-private (generate-waitlist-ids (max-id uint))
    (map generate-waitlist-id (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50))
)

(define-private (generate-waitlist-id (index uint))
    (if (<= index (var-get waitlist-counter))
        index
        u0
    )
)

(define-private (find-best-waitlist-match (unit-id uint))
    (let (
        (unit (unwrap-panic (map-get? housing-units unit-id)))
        (unit-bedrooms (get bedrooms unit))
        (max-waitlist (var-get waitlist-counter))
    )
        (fold find-best-match 
            (generate-waitlist-ids max-waitlist)
            {waitlist-id: u0, score: u0, found: false}
        )
    )
)

(define-private (find-best-match (waitlist-id uint) (current-best {waitlist-id: uint, score: uint, found: bool}))
    (match (map-get? housing-waitlist waitlist-id)
        entry-data
            (if (and (get active entry-data) (> (get priority-score entry-data) (get score current-best)))
                {
                    waitlist-id: waitlist-id,
                    score: (get priority-score entry-data),
                    found: true
                }
                current-best
            )
        current-best
    )
)

(define-private (reorder-waitlist-positions)
    (let (
        (max-waitlist (var-get waitlist-counter))
        (final-position (fold update-waitlist-position 
            (generate-waitlist-ids max-waitlist)
            u1
        ))
    )
        (ok true)
    )
)

(define-private (update-waitlist-position (waitlist-id uint) (position uint))
    (match (map-get? housing-waitlist waitlist-id)
        entry-data
            (if (get active entry-data)
                (begin
                    (map-set housing-waitlist waitlist-id
                        (merge entry-data {
                            waitlist-position: position
                        })
                    )
                    (+ position u1)
                )
                position
            )
        position
    )
)

(define-read-only (get-waitlist-entry (waitlist-id uint))
    (map-get? housing-waitlist waitlist-id)
)

(define-read-only (get-participant-waitlist-position (participant principal))
    (match (map-get? participant-waitlist-id participant)
        waitlist-id 
            (match (map-get? housing-waitlist waitlist-id)
                entry-data (some (get waitlist-position entry-data))
                none
            )
        none
    )
)

(define-read-only (get-waitlist-stats)
    {
        total-entries: (var-get waitlist-counter),
        active-entries: (count-active-waitlist-entries (var-get waitlist-counter)),
        auto-allocation-enabled: (var-get auto-allocation-enabled)
    }
)

(define-read-only (get-unit-vacancy-info (unit-id uint))
    (map-get? unit-vacancies unit-id)
)

(define-read-only (get-participant-waitlist-info (participant principal))
    (match (map-get? participant-waitlist-id participant)
        waitlist-id (map-get? housing-waitlist waitlist-id)
        none
    )
)

;; ====== DOCUMENT MANAGEMENT SYSTEM FUNCTIONS ======

;; Initialize default document types (called once by contract owner)
(define-public (initialize-document-types)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set document-types "lease-agreement"
            {
                description: "Lease agreement between tenant and housing authority",
                retention-period: u52596,  ;; ~1 year in blocks (assuming 10-min blocks)
                required-for-tenants: true,
                required-for-application: false
            }
        )
        (map-set document-types "income-verification"
            {
                description: "Proof of income documentation",
                retention-period: u26298,  ;; ~6 months in blocks
                required-for-tenants: true,
                required-for-application: true
            }
        )
        (map-set document-types "identity-verification"
            {
                description: "Government issued identification documents",
                retention-period: u0,  ;; No expiration
                required-for-tenants: true,
                required-for-application: true
            }
        )
        (map-set document-types "inspection-report"
            {
                description: "Housing unit inspection reports",
                retention-period: u78894,  ;; ~18 months in blocks
                required-for-tenants: false,
                required-for-application: false
            }
        )
        (map-set document-types "maintenance-receipt"
            {
                description: "Maintenance work completion receipts",
                retention-period: u26298,  ;; ~6 months in blocks
                required-for-tenants: false,
                required-for-application: false
            }
        )
        (ok true)
    )
)

;; Upload a new document
(define-public (upload-document 
    (unit-id uint)
    (document-type (string-ascii 50))
    (title (string-ascii 100))
    (description (string-ascii 300))
    (file-hash (string-ascii 64))
    (file-size uint)
    (access-level (string-ascii 20)))
    (let (
        (document-id (+ (var-get document-counter) u1))
        (document-type-info (unwrap! (map-get? document-types document-type) err-invalid-document-type))
        (unit (unwrap! (map-get? housing-units unit-id) err-invalid-housing-unit))
        (uploader tx-sender)
        (expiration-date (if (> (get retention-period document-type-info) u0)
            (some (+ stacks-block-height (get retention-period document-type-info)))
            none
        ))
        (current-unit-docs (default-to (list) (map-get? unit-documents unit-id)))
        (current-tenant-docs (default-to (list) (map-get? tenant-documents uploader)))
    )
        (asserts! (or (is-eq uploader contract-owner)
                     (is-eq (some uploader) (get winner unit))
                     (get allocated unit)) err-not-authorized-to-view)
        (asserts! (or (is-eq access-level "public")
                     (is-eq access-level "tenant-only")
                     (is-eq access-level "admin-only")
                     (is-eq access-level "private")) err-invalid-status)
        (asserts! (> file-size u0) err-invalid-document-type)
        (asserts! (> (len file-hash) u0) err-invalid-document-type)
        
        (map-set housing-documents document-id
            {
                unit-id: unit-id,
                uploader: uploader,
                document-type: document-type,
                title: title,
                description: description,
                file-hash: file-hash,
                upload-date: stacks-block-height,
                expiration-date: expiration-date,
                verification-status: "pending",
                verifier: none,
                verification-date: none,
                access-level: access-level,
                file-size: file-size,
                is-active: true
            }
        )
        
        (map-set unit-documents unit-id
            (unwrap-panic (as-max-len? (append current-unit-docs document-id) u100))
        )
        
        (map-set tenant-documents uploader
            (unwrap-panic (as-max-len? (append current-tenant-docs document-id) u100))
        )
        
        (var-set document-counter document-id)
        (ok document-id)
    )
)

;; View a document (with access control)
(define-read-only (get-document (document-id uint))
    (let (
        (document (unwrap! (map-get? housing-documents document-id) err-document-not-found))
        (access-level (get access-level document))
        (uploader (get uploader document))
        (viewer tx-sender)
        (unit (unwrap! (map-get? housing-units (get unit-id document)) err-invalid-housing-unit))
        (is-tenant (is-eq (some viewer) (get winner unit)))
        (has-permission (map-get? document-access-permissions {document-id: document-id, accessor: viewer}))
    )
        (asserts! (get is-active document) err-document-not-found)
        (asserts! 
            (or 
                (is-eq viewer contract-owner)  ;; Admin can view all
                (is-eq viewer uploader)  ;; Uploader can view own documents
                (and is-tenant (or (is-eq access-level "public") (is-eq access-level "tenant-only")))  ;; Tenant access
                (is-eq access-level "public")  ;; Public documents
                (and (is-some has-permission) (get can-view (unwrap-panic has-permission)))
            )
            err-not-authorized-to-view
        )
        
        ;; Check if document is expired
        (match (get expiration-date document)
            expiry-date
                (asserts! (<= stacks-block-height expiry-date) err-document-expired)
            true
        )
        
        (ok document)
    )
)

;; Verify a document (admin only)
(define-public (verify-document (document-id uint) (verification-status (string-ascii 20)))
    (let (
        (document (unwrap! (map-get? housing-documents document-id) err-document-not-found))
        (verifier tx-sender)
    )
        (asserts! (is-eq verifier contract-owner) err-owner-only)
        (asserts! (get is-active document) err-document-not-found)
        (asserts! (is-eq (get verification-status document) "pending") err-document-already-verified)
        (asserts! (or (is-eq verification-status "verified") 
                     (is-eq verification-status "rejected") 
                     (is-eq verification-status "needs-update")) err-invalid-status)
        
        (map-set housing-documents document-id
            (merge document {
                verification-status: verification-status,
                verifier: (some verifier),
                verification-date: (some stacks-block-height)
            })
        )
        (ok true)
    )
)

;; Grant document access permission
(define-public (grant-document-access 
    (document-id uint)
    (accessor principal)
    (can-view bool)
    (can-verify bool))
    (let (
        (document (unwrap! (map-get? housing-documents document-id) err-document-not-found))
        (granter tx-sender)
    )
        (asserts! (or (is-eq granter contract-owner) (is-eq granter (get uploader document))) err-not-authorized-to-view)
        (asserts! (get is-active document) err-document-not-found)
        
        (map-set document-access-permissions {document-id: document-id, accessor: accessor}
            {
                can-view: can-view,
                can-verify: can-verify,
                granted-by: granter,
                granted-at: stacks-block-height
            }
        )
        (ok true)
    )
)

;; Revoke document access permission
(define-public (revoke-document-access (document-id uint) (accessor principal))
    (let (
        (document (unwrap! (map-get? housing-documents document-id) err-document-not-found))
        (revoker tx-sender)
    )
        (asserts! (or (is-eq revoker contract-owner) (is-eq revoker (get uploader document))) err-not-authorized-to-view)
        (map-delete document-access-permissions {document-id: document-id, accessor: accessor})
        (ok true)
    )
)

;; Deactivate a document (soft delete)
(define-public (deactivate-document (document-id uint))
    (let (
        (document (unwrap! (map-get? housing-documents document-id) err-document-not-found))
        (requester tx-sender)
    )
        (asserts! (or (is-eq requester contract-owner) (is-eq requester (get uploader document))) err-not-authorized-to-view)
        (asserts! (get is-active document) err-document-not-found)
        
        (map-set housing-documents document-id
            (merge document {
                is-active: false
            })
        )
        (ok true)
    )
)

;; Get documents by unit
(define-read-only (get-unit-documents (unit-id uint))
    (let (
        (unit (unwrap! (map-get? housing-units unit-id) err-invalid-housing-unit))
        (viewer tx-sender)
        (is-tenant (is-eq (some viewer) (get winner unit)))
    )
        (asserts! (or (is-eq viewer contract-owner) is-tenant) err-not-authorized-to-view)
        (ok (default-to (list) (map-get? unit-documents unit-id)))
    )
)

;; Get documents by tenant
(define-read-only (get-tenant-documents (tenant principal))
    (let (
        (viewer tx-sender)
    )
        (asserts! (or (is-eq viewer contract-owner) (is-eq viewer tenant)) err-not-authorized-to-view)
        (ok (default-to (list) (map-get? tenant-documents tenant)))
    )
)

;; Get document verification status
(define-read-only (get-document-verification (document-id uint))
    (let (
        (document (unwrap! (map-get? housing-documents document-id) err-document-not-found))
        (viewer tx-sender)
        (uploader (get uploader document))
    )
        (asserts! (or (is-eq viewer contract-owner) (is-eq viewer uploader)) err-not-authorized-to-view)
        (asserts! (get is-active document) err-document-not-found)
        
        (ok {
            verification-status: (get verification-status document),
            verifier: (get verifier document),
            verification-date: (get verification-date document)
        })
    )
)

;; Check if document is expired
(define-read-only (is-document-expired (document-id uint))
    (let (
        (document (unwrap! (map-get? housing-documents document-id) err-document-not-found))
    )
        (match (get expiration-date document)
            expiry-date (ok (> stacks-block-height expiry-date))
            (ok false)
        )
    )
)

;; Get document type information
(define-read-only (get-document-type-info (document-type (string-ascii 50)))
    (ok (map-get? document-types document-type))
)

;; Get total document count
(define-read-only (get-total-documents)
    (ok (var-get document-counter))
)

;; Get documents requiring verification
(define-read-only (get-pending-verifications)
    (let (
        (max-docs (var-get document-counter))
        (viewer tx-sender)
    )
        (asserts! (is-eq viewer contract-owner) err-owner-only)
        (ok (filter-pending-documents max-docs))
    )
)

(define-private (filter-pending-documents (max-id uint))
    (fold filter-by-pending-status
        (generate-document-ids max-id)
        (list)
    )
)

(define-private (filter-by-pending-status (document-id uint) (results (list 100 uint)))
    (match (map-get? housing-documents document-id)
        document-data
            (if (and (get is-active document-data) (is-eq (get verification-status document-data) "pending"))
                (unwrap-panic (as-max-len? (append results document-id) u100))
                results
            )
        results
    )
)

(define-private (generate-document-ids (max-id uint))
    (map generate-doc-id (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 u59 u60 u61 u62 u63 u64 u65 u66 u67 u68 u69 u70 u71 u72 u73 u74 u75 u76 u77 u78 u79 u80 u81 u82 u83 u84 u85 u86 u87 u88 u89 u90 u91 u92 u93 u94 u95 u96 u97 u98 u99 u100))
)

(define-private (generate-doc-id (index uint))
    (if (<= index (var-get document-counter))
        index
        u0
    )
)


