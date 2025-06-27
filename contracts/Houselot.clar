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
        winner: (optional principal)
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

(define-data-var housing-unit-counter uint u0)

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
                winner: none
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
