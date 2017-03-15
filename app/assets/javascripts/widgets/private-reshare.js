$(document).ready(function() {

  $('#aspect_stream_container').arrive('.post-content', function() {
    post_content = $(this)

    post_content.find('a[href*="posts"]').each(function() {
      link = $(this)

      if (!(link.parents('.quoted-post').size() > 0)) {
        (function(link) {
          url = link.attr('href')
          json_url = `${url}.json`

          $.get(json_url, function(result) {
            if (result.text) {
              quote = $(`
                <div class="quoted-post reshare">
                  <div class="media">
                    <a class="img hovercardable"><img class="avatar" /></a>
                    <div class="bd">
                      <div class="quote-header">
                        <a class="author-link author-name hovercardable"></a>
                        <span class="details grey">
                          -
                          <a class="post-link"><time class="timeago"></time></a>
                        </span>
                      </div>
                      <div class="quote-content"></div>
                    </div>
                  </div>
                </div>
              `)

              quote.find('img.avatar')
                .attr('src', result.author.avatar.small)
              quote.find('a.author-link')
                .html(result.author.name)
                .attr('href', `/people/${result.author.guid}`)
              quote.find('a.post-link')
                .attr('href', `/posts/${result.guid}`)
              quote.find('.timeago')
                .html(result.created_at)
                .attr('datetime', result.created_at)
              app.helpers.timeago(quote)
              quote.find('.quote-content')
                .html(app.helpers.textFormatter(result.text))

              link.replaceWith(quote)
            }
          })
        }(link))
      }
    })
  })

})