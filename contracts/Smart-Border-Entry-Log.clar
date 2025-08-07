(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_ENTRY (err u402))
(define-constant ERR_ENTRY_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXITED (err u405))

(define-constant ERR_HEALTH_OFFICER_UNAUTHORIZED (err u406))
(define-constant ERR_INVALID_HEALTH_STATUS (err u407))
(define-constant ERR_HEALTH_DECLARATION_EXISTS (err u408))

(define-data-var next-entry-id uint u1)

(define-map authorized-agents principal bool)
(define-map border-entries uint {
    traveler: principal,
    entry-point: (string-ascii 50),
    destination: (string-ascii 50),
    entry-type: (string-ascii 10),
    timestamp: uint,
    block-height: uint,
    status: (string-ascii 10),
    exit-timestamp: (optional uint),
    exit-point: (optional (string-ascii 50))
})

(define-map traveler-entries principal (list 100 uint))
(define-map entry-statistics (string-ascii 50) {
    total-entries: uint,
    total-exits: uint,
    active-travelers: uint
})

(define-public (add-authorized-agent (agent principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-agents agent true)
        (ok true)
    )
)

(define-public (remove-authorized-agent (agent principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-delete authorized-agents agent)
        (ok true)
    )
)

(define-public (log-entry (traveler principal) (entry-point (string-ascii 50)) (destination (string-ascii 50)) (entry-type (string-ascii 10)))
    (let (
        (entry-id (var-get next-entry-id))
        (current-block stacks-block-height)
        (current-entries (default-to (list) (map-get? traveler-entries traveler)))
        (current-stats (default-to {total-entries: u0, total-exits: u0, active-travelers: u0} (map-get? entry-statistics entry-point)))
    )
        (asserts! (default-to false (map-get? authorized-agents tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (> (len entry-point) u0) ERR_INVALID_ENTRY)
        (asserts! (> (len destination) u0) ERR_INVALID_ENTRY)
        (asserts! (or (is-eq entry-type "entry") (is-eq entry-type "transit")) ERR_INVALID_ENTRY)
        
        (map-set border-entries entry-id {
            traveler: traveler,
            entry-point: entry-point,
            destination: destination,
            entry-type: entry-type,
            timestamp: stacks-block-height,
            block-height: current-block,
            status: "active",
            exit-timestamp: none,
            exit-point: none
        })
        
        (map-set traveler-entries traveler (unwrap! (as-max-len? (append current-entries entry-id) u100) ERR_INVALID_ENTRY))
        
        (map-set entry-statistics entry-point {
            total-entries: (+ (get total-entries current-stats) u1),
            total-exits: (get total-exits current-stats),
            active-travelers: (+ (get active-travelers current-stats) u1)
        })
        
        (var-set next-entry-id (+ entry-id u1))
        (ok entry-id)
    )
)

(define-public (log-exit (entry-id uint) (exit-point (string-ascii 50)))
    (let (
        (entry-data (unwrap! (map-get? border-entries entry-id) ERR_ENTRY_NOT_FOUND))
        (entry-point-name (get entry-point entry-data))
        (current-stats (default-to {total-entries: u0, total-exits: u0, active-travelers: u0} (map-get? entry-statistics entry-point-name)))
    )
        (asserts! (default-to false (map-get? authorized-agents tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status entry-data) "active") ERR_ALREADY_EXITED)
        (asserts! (> (len exit-point) u0) ERR_INVALID_ENTRY)
        
        (map-set border-entries entry-id (merge entry-data {
            status: "exited",
            exit-timestamp: (some stacks-block-height),
            exit-point: (some exit-point)
        }))
        
        (map-set entry-statistics entry-point-name {
            total-entries: (get total-entries current-stats),
            total-exits: (+ (get total-exits current-stats) u1),
            active-travelers: (- (get active-travelers current-stats) u1)
        })
        
        (ok true)
    )
)

(define-public (update-entry-status (entry-id uint) (new-status (string-ascii 10)))
    (let (
        (entry-data (unwrap! (map-get? border-entries entry-id) ERR_ENTRY_NOT_FOUND))
    )
        (asserts! (default-to false (map-get? authorized-agents tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (or (is-eq new-status "active") (is-eq new-status "flagged") (is-eq new-status "cleared")) ERR_INVALID_ENTRY)
        
        (map-set border-entries entry-id (merge entry-data {status: new-status}))
        (ok true)
    )
)

(define-read-only (get-entry (entry-id uint))
    (map-get? border-entries entry-id)
)

(define-read-only (get-traveler-entries (traveler principal))
    (default-to (list) (map-get? traveler-entries traveler))
)

(define-read-only (get-entry-statistics (entry-point (string-ascii 50)))
    (default-to {total-entries: u0, total-exits: u0, active-travelers: u0} (map-get? entry-statistics entry-point))
)

(define-read-only (is-authorized-agent (agent principal))
    (default-to false (map-get? authorized-agents agent))
)

(define-read-only (get-contract-owner)
    CONTRACT_OWNER
)

(define-read-only (get-next-entry-id)
    (var-get next-entry-id)
)

(define-read-only (get-traveler-active-entries (traveler principal))
    (let (
        (entry-ids (get-traveler-entries traveler))
    )
        (filter is-entry-active entry-ids)
    )
)

(define-private (is-entry-active (entry-id uint))
    (match (map-get? border-entries entry-id)
        entry-data (is-eq (get status entry-data) "active")
        false
    )
)

(define-read-only (get-entry-point-active-count (entry-point (string-ascii 50)))
    (get active-travelers (get-entry-statistics entry-point))
)

(define-read-only (get-traveler-last-entry (traveler principal))
    (let (
        (entries (get-traveler-entries traveler))
    )
        (if (> (len entries) u0)
            (match (element-at entries (- (len entries) u1))
                last-entry-id (map-get? border-entries last-entry-id)
                none
            )
            none
        )
    )
)

(map-set authorized-agents CONTRACT_OWNER true)


(define-map authorized-health-officers principal bool)
(define-map health-declarations uint {
    declaration-type: (string-ascii 20),
    health-status: (string-ascii 15),
    temperature: (optional uint),
    symptoms: (string-ascii 100),
    clearance-status: (string-ascii 10),
    officer: principal,
    declaration-timestamp: uint,
    clearance-timestamp: (optional uint)
})

(define-map entry-health-mapping uint uint)

(define-public (add-health-officer (officer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-health-officers officer true)
        (ok true)
    )
)

(define-public (record-health-declaration 
    (entry-id uint) 
    (declaration-type (string-ascii 20))
    (health-status (string-ascii 15))
    (temperature (optional uint))
    (symptoms (string-ascii 100)))
    (begin
        (asserts! (default-to false (map-get? authorized-health-officers tx-sender)) ERR_HEALTH_OFFICER_UNAUTHORIZED)
        (asserts! (is-some (map-get? border-entries entry-id)) ERR_ENTRY_NOT_FOUND)
        (asserts! (is-none (map-get? entry-health-mapping entry-id)) ERR_HEALTH_DECLARATION_EXISTS)
        (asserts! (or (is-eq health-status "healthy") (is-eq health-status "symptomatic") (is-eq health-status "fever")) ERR_INVALID_HEALTH_STATUS)
        
        (map-set health-declarations entry-id {
            declaration-type: declaration-type,
            health-status: health-status,
            temperature: temperature,
            symptoms: symptoms,
            clearance-status: "pending",
            officer: tx-sender,
            declaration-timestamp: stacks-block-height,
            clearance-timestamp: none
        })
        
        (map-set entry-health-mapping entry-id entry-id)
        (ok entry-id)
    )
)

(define-public (update-health-clearance (entry-id uint) (clearance-status (string-ascii 10)))
    (let (
        (health-data (unwrap! (map-get? health-declarations entry-id) ERR_ENTRY_NOT_FOUND))
    )
        (asserts! (default-to false (map-get? authorized-health-officers tx-sender)) ERR_HEALTH_OFFICER_UNAUTHORIZED)
        (asserts! (or (is-eq clearance-status "cleared") (is-eq clearance-status "rejected") (is-eq clearance-status "quarantine")) ERR_INVALID_HEALTH_STATUS)
        
        (map-set health-declarations entry-id (merge health-data {
            clearance-status: clearance-status,
            clearance-timestamp: (some stacks-block-height)
        }))
        (ok true)
    )
)

(define-read-only (get-health-declaration (entry-id uint))
    (map-get? health-declarations entry-id)
)

(define-read-only (is-health-officer (officer principal))
    (default-to false (map-get? authorized-health-officers officer))
)

(define-read-only (get-entry-health-status (entry-id uint))
    (match (map-get? health-declarations entry-id)
        health-data (some (get clearance-status health-data))
        none
    )
)