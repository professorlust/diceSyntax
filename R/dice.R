#' @export
insertRoll = function(){
    rstudioapi::insertText('r(r')
}

#' Roll a dice
#' @description Rolls the dice described as a string
#' @param dice character. If a variable name, the variable must not be a valid dice syntax that starts with an r or the function will just roll that dice instead (eg. r4d6). description of the dice to be rolled. 4d6 rolls four six sided dice. 4d6+3 adds 3 to the result. 4d6k3 keeps the highest 3 dice. 4d6d1 drops the lowest one dice. 4d6kl3 keeps the lowest 3 dice. 4d6dh1 drops the highest 1 dice. 4d6r1 rerolls all 1s. 4d6ro1 rerolls 1s once. 4df rolls fate dice.
#' @param vocal Should it print individual rolls
#' @param returnRolls Logical. If true a list will be returned that includes rolled and dropped dice as well as the sum of accepted dice
#' @export
roll = function(dice, critMark = TRUE,vocal=TRUE,returnRolls = FALSE){
    diceSubstitute = as.character(substitute(dice))

    if(any(grepl('^r[0-9]+d[0-9]+',diceSubstitute))){
        dice = diceSubstitute
    }

    if(length(dice)>1){
        dice = paste0(dice[2],dice[1],dice[3])
    }

    rollingRules = diceParser(dice)

    # end
    rollParam(rollingRules$diceCount,
              rollingRules$diceSide,
              rollingRules$fate,
              rollingRules$sort,
              rollingRules$dropDice,
              rollingRules$dropLowest,
              rollingRules$add,
              rollingRules[['reroll']],
              rollingRules$rerollOnce,
              rollingRules$explode,
              critMark,
              vocal,
              returnRolls)

}

#' @export
r = roll


#' @export
diceStats = function(dice,n=1000){
    rolls = sapply(1:n,function(i){roll(dice,vocal = FALSE)})
    plot = data.frame(rolls = rolls) %>%
        ggplot2::ggplot(ggplot2::aes(x = rolls)) + cowplot::theme_cowplot() +
        ggplot2::geom_density(fill = 'grey')
    mean = mean(rolls)
    return(list(mean,plot))
}

#' @export
diceProb = function(dice){
    rollingRules = diceParser(dice)

    if(!rollingRules$fate){
        possibleDice = (1:rollingRules$diceSide)[!1:rollingRules$diceSide %in% rollingRules$reroll]
    } else{
        possibleDice  = (-1:1)[!-1:1 %in% rollingRules$reroll]
    }

    baseProb = 1/length(possibleDice)

    # matrix has no reason to be here. it may in the future with exploding though..

    diceProbs = matrix(1/length(possibleDice),
                       nrow = length(possibleDice),
                       ncol = rollingRules$diceCount)
    row.names(diceProbs) = possibleDice

    if(length(rollingRules$rerollOnce)>0){
        diceProbsToAdd = matrix(0,
                                nrow = length(possibleDice),
                                ncol = rollingRules$diceCount)
        for (x in rollingRules$rerollOnce[rollingRules$rerollOnce %in% possibleDice]){
            diceProbs[x %>% as.character(),] = 0
            diceProbsToAdd = diceProbsToAdd + baseProb^2
        }
        diceProbs = diceProbs + diceProbsToAdd
    }

    allPossibs = expand.grid(rep(list(rownames(diceProbs) %>% as.integer()),ncol(diceProbs)))

    probabilities = apply(allPossibs,1,function(x){
        sapply(seq(ncol(diceProbs)),function(i){
            diceProbs[x[i] %>% unlist %>% as.character,i]
        }) %>% prod
    })

    possibSums = allPossibs %>% apply(1,function(x){
        dropDice = rollingRules$dropDice
        dropLowest = rollingRules$dropLowest
        if(!is.null(dropDice)){
            drop = x[order(x,decreasing = !dropLowest)[1:dropDice] %>% sort]
            x =  x[-order(x,decreasing = !dropLowest)[1:dropDice] %>% sort]
        }
        sum(x)
    })

    possibleResults = unique(possibSums)

    resultProbs = possibleResults %>% sapply(function(x){
        sum(probabilities[possibSums %in% x])
    })


    names(resultProbs) = possibleResults
    return(resultProbs)
}

# AC: armor class
# bonus: attack bonus of the group
# count: number of entities in the group
# advantage: N = normal. A = with advantage, D = with disadvantage
# dice = number and type of die
# damageBonus = bonus to damage
# default settings are for animating 10 tiny objects but should work with any mob of identical creatures
#' @export
animate = function(AC, bonus = 8, count = 10, advantage = 'N', dice = '1d4' , damageBonus = 4){
    out = sapply(1:count, function(x){
        out = sample(1:20,size = 1)
        if (advantage == 'A'){
            out2 = sample(1:20,size = 1)
            out = max(out,out2)
        } else if(advantage == 'D'){
            out2 = sample(1:20,size = 1)
            out = min(out,out2)
        }
        return(out)
    })

    diceCount = as.integer(regmatches(dice,regexpr(".*?(?=d)",dice,perl = T)))
    diceSide = as.integer(regmatches(dice,regexpr("(?<=d).*",dice,perl = T)))

    sum(
        sapply(out,function(x){
            if(x == 20){
                return(sum(sample(1:diceSide,diceCount*2,replace=T)) + damageBonus)
            } else if(x==1){
                return(0)
            }else{
                if ((x + bonus - AC) >= 0){
                    return(sample(1:diceSide,diceCount,replace=T) + damageBonus)
                } else {
                    return(0)
                }
            }
        }))
}
