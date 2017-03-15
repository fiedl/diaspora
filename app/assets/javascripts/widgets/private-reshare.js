$(document).ready(function() {

  // Monitor appearing posts.
  $('#aspect_stream_container').arrive('.post-content', function() {
    post_content = $(this)
    stream_element = post_content.closest('.stream-element')

    // Replace links to other posts with quotes ("reshares").
    post_content.find('a[href*="posts"]').each(function() {
      link = $(this)

      if (
        !(link.parents('.reshare').size() > 0) &&
        link.text() == link.attr('href')
      ) {
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

              if (result.photos.length > 0) {
                image = $('<img src="" />')
                image.attr('src', result.photos[0].sizes.large)
                quote.find('.quote-content').prepend(image)
              }

              link.replaceWith(quote)
            }
          })
        }(link))
      }
    })

    // Add a "private reshare" button.
    stream_element.find('.feedback').each(function() {
      feedback_section = $(this)
      reshare_link = feedback_section.find('a.reshare')

      post_path = stream_element.find('a.permalink').attr('href')
      post_url = `${window.location.origin}${post_path}`
      private_reshare_link = $(`
        <a href="${post_url}" class="private-reshare" rel="nofollow">
          ${Diaspora.I18n.t('private_reshares.private_reshare')}
        </a>
      `)

      reshare_link.after(private_reshare_link)
      reshare_link.after(" · ")
    })
  })

})

$(document).on('click', '#aspect_stream_container .feedback a.private-reshare', function(e) {
  private_reshare_link = $(this)
  post_url = private_reshare_link.attr('href')

  already_done = false
  $("html, body").animate({scrollTop: 0}, function() {
    if (! already_done) {
      already_done = true

      publisher_view = new app.views.Publisher
      publisher_view.open()
      publisher_view.setText(post_url)
      publisher_view.inputEl.focus()
    }
  })

  return false
})