;; Meal Planner Smart Contract
;; Module for suggesting recipes and creating shopping lists

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_RECIPE_NOT_FOUND (err u402))
(define-constant ERR_INVALID_DATA (err u403))

;; Data Variables
(define-data-var recipe-counter uint u0)
(define-data-var total-users uint u0)

;; Data Maps
(define-map recipes
    uint
    {
        name: (string-ascii 100),
        ingredients: (list 10 (string-ascii 50)),
        instructions: (string-ascii 500),
        prep-time: uint,
        servings: uint,
        difficulty: uint,
        category: (string-ascii 30),
        nutrition-calories: uint,
        is-active: bool
    }
)

(define-map user-preferences
    principal
    {
        dietary-restrictions: (list 5 (string-ascii 30)),
        favorite-cuisines: (list 5 (string-ascii 30)),
        cooking-skill: uint,
        budget-range: uint,
        family-size: uint,
        meal-frequency: uint
    }
)

(define-map meal-plans
    { user: principal, week: uint }
    {
        monday-breakfast: uint,
        monday-lunch: uint,
        monday-dinner: uint,
        tuesday-breakfast: uint,
        tuesday-lunch: uint,
        tuesday-dinner: uint,
        wednesday-breakfast: uint,
        wednesday-lunch: uint,
        wednesday-dinner: uint,
        thursday-breakfast: uint,
        thursday-lunch: uint,
        thursday-dinner: uint,
        friday-breakfast: uint,
        friday-lunch: uint,
        friday-dinner: uint,
        saturday-breakfast: uint,
        saturday-lunch: uint,
        saturday-dinner: uint,
        sunday-breakfast: uint,
        sunday-lunch: uint,
        sunday-dinner: uint,
        total-cost: uint,
        created-at: uint
    }
)

(define-map shopping-lists
    { user: principal, list-id: uint }
    {
        items: (list 50 (string-ascii 50)),
        quantities: (list 50 uint),
        estimated-cost: uint,
        store-preference: (string-ascii 50),
        priority-items: (list 10 (string-ascii 50)),
        generated-at: uint,
        is-completed: bool
    }
)

;; Public Functions

(define-public (create-recipe 
    (name (string-ascii 100))
    (ingredients (list 10 (string-ascii 50)))
    (instructions (string-ascii 500))
    (prep-time uint)
    (servings uint)
    (difficulty uint)
    (category (string-ascii 30))
    (calories uint)
)
    (let
        ((recipe-id (+ (var-get recipe-counter) u1)))
        (var-set recipe-counter recipe-id)
        (map-set recipes recipe-id
            {
                name: name,
                ingredients: ingredients,
                instructions: instructions,
                prep-time: prep-time,
                servings: servings,
                difficulty: difficulty,
                category: category,
                nutrition-calories: calories,
                is-active: true
            }
        )
        (ok recipe-id)
    )
)

(define-public (set-user-preferences
    (dietary-restrictions (list 5 (string-ascii 30)))
    (favorite-cuisines (list 5 (string-ascii 30)))
    (cooking-skill uint)
    (budget-range uint)
    (family-size uint)
    (meal-frequency uint)
)
    (begin
        (if (is-none (map-get? user-preferences tx-sender))
            (var-set total-users (+ (var-get total-users) u1))
            true
        )
        (map-set user-preferences tx-sender
            {
                dietary-restrictions: dietary-restrictions,
                favorite-cuisines: favorite-cuisines,
                cooking-skill: cooking-skill,
                budget-range: budget-range,
                family-size: family-size,
                meal-frequency: meal-frequency
            }
        )
        (ok "Preferences updated successfully")
    )
)

(define-public (generate-meal-plan (user principal) (week uint))
    (let
        ((user-prefs (unwrap! (map-get? user-preferences user) ERR_NOT_AUTHORIZED)))
        (map-set meal-plans { user: user, week: week }
            {
                monday-breakfast: u1,
                monday-lunch: u2,
                monday-dinner: u3,
                tuesday-breakfast: u4,
                tuesday-lunch: u5,
                tuesday-dinner: u6,
                wednesday-breakfast: u7,
                wednesday-lunch: u8,
                wednesday-dinner: u9,
                thursday-breakfast: u10,
                thursday-lunch: u11,
                thursday-dinner: u12,
                friday-breakfast: u13,
                friday-lunch: u14,
                friday-dinner: u15,
                saturday-breakfast: u16,
                saturday-lunch: u17,
                saturday-dinner: u18,
                sunday-breakfast: u19,
                sunday-lunch: u20,
                sunday-dinner: u21,
                total-cost: u500,
                created-at: stacks-block-height
            }
        )
        (ok "Meal plan generated successfully")
    )
)

(define-public (create-shopping-list (user principal) (list-id uint) (week uint))
    (let
        ((meal-plan (unwrap! (map-get? meal-plans { user: user, week: week }) ERR_NOT_AUTHORIZED)))
        (map-set shopping-lists { user: user, list-id: list-id }
            {
                items: (list "Eggs" "Milk" "Bread" "Chicken" "Rice" "Vegetables" "Fruits" "Spices" "Oil" "Butter"),
                quantities: (list u12 u1 u2 u2 u1 u5 u3 u1 u1 u1),
                estimated-cost: (get total-cost meal-plan),
                store-preference: "Local Market",
                priority-items: (list "Milk" "Bread" "Eggs"),
                generated-at: stacks-block-height,
                is-completed: false
            }
        )
        (ok "Shopping list created successfully")
    )
)

(define-public (mark-shopping-list-completed (user principal) (list-id uint))
    (let
        ((current-list (unwrap! (map-get? shopping-lists { user: user, list-id: list-id }) ERR_NOT_AUTHORIZED)))
        (map-set shopping-lists { user: user, list-id: list-id }
            (merge current-list { is-completed: true })
        )
        (ok "Shopping list marked as completed")
    )
)

;; Read-only functions

(define-read-only (get-recipe (recipe-id uint))
    (map-get? recipes recipe-id)
)

(define-read-only (get-user-preferences (user principal))
    (map-get? user-preferences user)
)

(define-read-only (get-meal-plan (user principal) (week uint))
    (map-get? meal-plans { user: user, week: week })
)

(define-read-only (get-shopping-list (user principal) (list-id uint))
    (map-get? shopping-lists { user: user, list-id: list-id })
)

(define-read-only (get-recipe-count)
    (var-get recipe-counter)
)

(define-read-only (get-total-users)
    (var-get total-users)
)

