#' @export
insertRoll = function(){
    rstudioapi::insertText(' %>% (diceSyntax::roll)')
}

#' @export
roll = function(dice, vocal=TRUE){
    dice = substitute(dice) %>% as.character()
    if(length(dice)>1){
        dice = paste0(dice[2],dice[1],dice[3])
    }
    dice %<>% stringr::str_replace('^r|R','')
    rollingRules = list()
    validTokens = "[dkscrf+\\-!DKSCRF]"
    dice %<>% tolower  %>% gsub(pattern = '\\s',replacement = '',x = .)
    rollingRules$diceCount = stringr::str_extract(string = dice,pattern =  '^[0-9]+?(?=d)') %>% as.integer()
    otherTokens =  stringr::str_extract_all(string = dice,
                                            pattern =  paste0(validTokens,'.*?((?=',validTokens, ')|$)')) %>% unlist


    rollingRules$diceSide = stringr::str_extract(string = otherTokens[1],pattern =  '(?<=d)[0-9f]*')
    if( rollingRules$diceSide == '' &  otherTokens[2] == 'f'){
        rollingRules$diceSide = 3
        rollingRules$fate = TRUE
        otherTokens = otherTokens[-1]
    } else{
        rollingRules$fate = FALSE
    }

    if(rollingRules$diceSide == ''){
        stop('First parameter has to be dice side (eg. "1d6")')
    }

    otherTokens = otherTokens[-1]

    # sort the dice if s token is added ------------
    if('s' %in%  otherTokens){
        rollingRules$sort = TRUE
    } else{
        rollingRules$sort = FALSE
    }

    # drop dice if rules are given --------------
    dropRules = otherTokens %>% {.[grep(pattern = 'd|k',.)]}
    if(length(dropRules)>1){
        stop('Conflicting keep options given')
    } else if(length(dropRules)==0){
        rollingRules$dropDice = NULL
        rollingRules$dropLowest = TRUE # default configuration
    } else{
        dropNo = stringr::str_extract(string = dropRules,pattern =  '[0-9]+') %>% as.integer
        if(length(dropNo)==0){
            stop('Keep options require number of dice to keep or drop (eg. 10d6k3 10d6d3)')
        }
        rollingRules$dropDice = switch(substr(dropRules,1,1),
                                       d =  dropNo,
                                       k =  rollingRules$diceCount-dropNo)
        rollingRules$dropLowest = !(grepl(pattern = 'dh',dropRules) | grepl(pattern ='kl', dropRules))
    }

    # additon or substraction -----------------
    aditionRules = otherTokens %>% {.[grep(pattern = '\\+|-',.)]} %>% as.integer()
    if(any(is.na(aditionRules))){
        stop('"-" and "+" should always be followed by integers')
    }
    if(length(aditionRules)!=0){
        rollingRules$add = sum(aditionRules)
    } else{
        rollingRules$add = 0
    }


    # reroll ---------------------
    rerollDetermine = function(x){
        number=  stringr::str_extract(x,'[0-9]*$')
        if(grepl('<|>',x) & number ==''){
            stop('Rerolling with "<" or ">" identifiers requires an integer')
        } else if(grepl('<',x) & grepl('>',x)){
            stop('Single rerolling clause can only have one of "<" or ">"')
        } else if(!grepl('<|>',x) & number ==''){
            reroll = 1
            if (rollingRules$fate){
                reroll = -1
            }
        } else if(!grepl('<|>',x) & number!=''){
            reroll = number %>% as.integer()
        } else if (grepl('<',x)){
            reroll = 1:number
            if(rollingRules$fate){
                reroll = -1:number
            }
        } else if(grepl('>',x)){
            reroll = number:rollingRules$diceSide
            if(rollingRules$fate){
                reroll = number:1
            }
        }
        return(reroll)
    }

    rerollRules = otherTokens %>% {.[grep(pattern = 'r(?!o)',.,perl=TRUE)]}

    reroll = rerollRules %>% lapply(rerollDetermine) %>% unlist
    dicePossibilities = 1:rollingRules$diceSide
    if(rollingRules$fate){
        dicePossibilities = -1:1
    }
    if(all(dicePossibilities %in% reroll)){
        stop('You cannot reroll every possible result')
    }
    rollingRules$reroll = reroll


    rerollOnceRules = otherTokens %>% {.[grep(pattern = 'ro',.,perl=TRUE)]}
    rerollOnce = rerollOnceRules %>% lapply(rerollDetermine) %>% unlist
    if(length(intersect(reroll,rerollOnce))>0){
        warning('Why reroll something once and forever?')
    }
    rollingRules$rerollOnce = rerollOnce


    # end
    rollParam(rollingRules$diceCount,
              rollingRules$diceSide,
              rollingRules$fate,
              rollingRules$sort,
              rollingRules$dropDice,
              rollingRules$dropLowest,
              rollingRules$add,
              rollingRules$reroll,
              rollingRules$rerollOnce,
              vocal)

}

#' @export
r = roll

#' @export
rollParam = function(diceCount,
                     diceSide = NULL,
                     fate = FALSE,
                     sort = FALSE,
                     dropDice = NULL,
                     dropLowest = TRUE,
                     add = 0,
                     reroll = c(),
                     rerollOnce = c(),
                     vocal=TRUE){
    resample <- function(x, ...) x[sample.int(length(x), ...)]

    if(!fate){
        dice = resample((1:diceSide)[!1:diceSide %in% reroll],diceCount,replace=TRUE)
    } else{
        dice = resample((-1:1)[!-1:1 %in% reroll],diceCount,replace=TRUE)
    }

    if(!is.null(dropDice)){
        drop = dice[order(dice,decreasing = !dropLowest)[1:dropDice] %>% sort]
        dice =  dice[-order(dice,decreasing = !dropLowest)[1:dropDice] %>% sort]
    }

    if(sort){
        dice = sort(dice)
        if(!is.null(dropDice)){
            drop = sort(drop)
        }
    }

    if(vocal){
        print(paste('Rolls: [',paste(dice,collapse=' '),']'))
        if(!is.null(dropDice)){
            print(paste('Dropped: [',paste(drop,collapse=' '),']'))
        }
    }
    result = sum(dice) + add
    return(result)
}

#' @export
diceStats = function(dice,n=1000){
    rolls = sapply(1:n,function(i){roll(dice,vocal = FALSE)})
    plot = data.frame(rolls = rolls) %>%
        ggplot2::ggplot(ggplot2::aes(x = rolls)) + cowplot::theme_cowplot() +
        ggplot2::geom_density(fill = 'grey')
    mean = mean(rolls)
    return(list(mean,plot))
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